import AppKit
import Foundation

struct Check: Identifiable {
    let id = UUID()
    let ok: Bool
    let title: String
    let hint: String?
}

struct Component: Identifiable {
    let id: String
    let name: String
    let version: String
    let kind: String
    let license: String
    let homepage: String
    let optional: Bool
    var installed: String?

    var upToDate: Bool { installed == version }
}

struct Mod: Identifiable {
    var id: String { name }
    let name: String
    let files: [String]
}

@MainActor
final class AppModel: ObservableObject {
    @Published var checks: [Check] = []
    @Published var components: [Component] = []
    @Published var mods: [Mod] = []
    @Published var log: [String] = []
    @Published var busy: String?
    @Published var gameRunning = false
    @Published var lastError: String?

    /// The game copy; the same default as the CLI (lib/common.sh).
    let game = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Games/Cyberpunk 2077 Ripperdoc")
    private var stateDir: URL { game.appendingPathComponent(".ripperdoc") }
    private var timer: Timer?

    var hasCopy: Bool { FileManager.default.fileExists(atPath: stateDir.appendingPathComponent("source").path) }
    var allInstalled: Bool { !components.isEmpty && components.filter { !$0.optional }.allSatisfy(\.upToDate) }
    var healthy: Bool { !checks.isEmpty && checks.allSatisfy(\.ok) }

    init() {
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.gameRunning = AppModel.isGameRunning() }
        }
        Task { await doctor() }
    }

    // MARK: state read from disk

    func reload() {
        components = readComponents()
        mods = readMods()
        gameRunning = Self.isGameRunning()
    }

    private func readComponents() -> [Component] {
        guard let root = CLI.root,
              let data = try? Data(contentsOf: root.appendingPathComponent("components.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["components"] as? [[String: Any]] else { return [] }
        return list.map { c in
            let id = c["id"] as? String ?? "?"
            let installed = try? String(contentsOf: stateDir.appendingPathComponent("installed.\(id)"), encoding: .utf8)
            return Component(id: id, name: c["name"] as? String ?? id, version: c["version"] as? String ?? "",
                             kind: c["kind"] as? String ?? "", license: c["license"] as? String ?? "",
                             homepage: c["homepage"] as? String ?? "", optional: c["optional"] as? Bool ?? false,
                             installed: installed?.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func readMods() -> [Mod] {
        let dir = stateDir.appendingPathComponent("mods")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "files" }.sorted { $0.path < $1.path }.map { url in
            let lines = (try? String(contentsOf: url, encoding: .utf8))?.split(separator: "\n").map(String.init) ?? []
            return Mod(name: url.deletingPathExtension().lastPathComponent, files: lines)
        }
    }

    static func isGameRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.executableURL?.path.hasSuffix("Cyberpunk2077.app/Contents/MacOS/Cyberpunk2077") == true
        }
    }

    // MARK: actions (all through the CLI)

    func doctor() async {
        final class Found { var checks: [Check] = [] }
        let found = Found()
        _ = await CLI.run(["doctor"]) { line in
            // "ok   <title>" or "warn <title>: NO (<hint>)"
            if line.hasPrefix("ok   ") {
                found.checks.append(Check(ok: true, title: String(line.dropFirst(5)), hint: nil))
            } else if line.hasPrefix("warn ") {
                var text = String(line.dropFirst(5))
                var hint: String?
                if let r = text.range(of: ": NO") {
                    let rest = text[r.upperBound...].trimmingCharacters(in: .whitespaces)
                    hint = rest.hasPrefix("(") ? String(rest.dropFirst().dropLast()) : nil
                    text = String(text[..<r.lowerBound])
                }
                found.checks.append(Check(ok: false, title: text, hint: hint))
            }
        }
        checks = found.checks
    }

    /// Run a CLI command that changes things, with its output in the log, then re-read the state.
    /// Returns the command's exit status (-1 when another command was already running).
    @discardableResult
    func perform(_ title: String, _ args: [String]) async -> Int32 {
        guard busy == nil else { return -1 }
        busy = title
        lastError = nil
        log.append("$ ripperdoc \(args.joined(separator: " "))")
        let status = await CLI.run(args) { [weak self] line in
            self?.log.append(line)
            if line.hasPrefix("error ") { self?.lastError = String(line.dropFirst(6)) }
        }
        if status != 0, lastError == nil { lastError = "\(title) failed (exit \(status)); see the log" }
        busy = nil
        reload()
        await doctor()
        return status
    }

    func setup() async { await perform("Setting up the game copy", ["setup"]) }
    func installAll() async { await perform("Installing frameworks", ["install"]) }
    func install(_ id: String) async { await perform("Installing \(id)", ["install", id]) }
    func refresh() async { await perform("Refreshing after a game update", ["refresh"]) }
    func addMod(_ url: URL) async {
        if await perform("Installing \(url.lastPathComponent)", ["mod", "add", url.path]) == 0 {
            support.considerAsking()
        }
    }
    func removeMod(_ name: String) async { await perform("Removing \(name)", ["mod", "remove", name]) }

    /// The game runs as long as the launcher does; its output (script compile, plugin logs) goes to the log.
    func play() {
        guard !gameRunning, busy == nil else { return }
        log.append("$ ripperdoc play")
        gameRunning = true
        let started = Date()
        Task { [weak self] in
            let status = await CLI.run(["play"]) { line in self?.log.append(line) }
            guard let self else { return }
            log.append("game exited (status \(status))")
            reload()
            // Ask after a real session that ended normally, when the player is back in the app; never at launch.
            if status == 0, Date().timeIntervalSince(started) > 120 {
                support.considerAsking()
            }
        }
    }

    let support = SupportPrompt()

    func revealGame() { NSWorkspace.shared.activateFileViewerSelecting([game]) }

    func revealLogs() {
        NSWorkspace.shared.open(game.appendingPathComponent("red4ext/logs"))
    }

    /// The game's console output of each play session (written by `ripperdoc play`).
    func revealPlayLogs() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Ripperdoc")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }
}
