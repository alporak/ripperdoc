import Foundation

/// Runs the bundled `ripperdoc` CLI. The app never reimplements what the CLI does; it only shows and drives it.
enum CLI {
    /// The folder that holds the `ripperdoc` script: inside the app bundle, or, when run from the repo (swift run / Xcode),
    /// the repository root.
    static var root: URL? {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("ripperdoc"),
           FileManager.default.isExecutableFile(atPath: bundled.appendingPathComponent("ripperdoc").path) {
            return bundled
        }
        if let env = ProcessInfo.processInfo.environment["RIPPERDOC_ROOT"] {
            return URL(fileURLWithPath: env)
        }
        // app/.build/<config>/Ripperdoc -> repository root
        var dir = Bundle.main.executableURL?.deletingLastPathComponent()
        for _ in 0..<6 {
            guard let d = dir else { break }
            if FileManager.default.isExecutableFile(atPath: d.appendingPathComponent("ripperdoc").path),
               FileManager.default.fileExists(atPath: d.appendingPathComponent("components.json").path) {
                return d
            }
            dir = d.deletingLastPathComponent()
        }
        return nil
    }

    /// Apps started from Finder get a minimal PATH; the CLI needs Homebrew's tools (cmake, cargo) and the system ones.
    static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = ["/opt/homebrew/bin", "/opt/homebrew/opt/rustup/bin", "/opt/homebrew/opt/dotnet@8/bin",
                     "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        env["PATH"] = (extra + [env["PATH"] ?? ""]).joined(separator: ":")
        env["NO_COLOR"] = "1"
        return env
    }

    /// Start `ripperdoc <args>` and stream its stdout and stderr, line by line, to `onLine` (on the main actor).
    /// Returns the exit status.
    @discardableResult
    static func run(_ args: [String], onLine: @escaping @MainActor (String) -> Void) async -> Int32 {
        guard let root else {
            await onLine("error ripperdoc CLI not found in the app bundle")
            return 127
        }
        let process = Process()
        // Run the script through the system's bash: files in a downloaded app carry the quarantine flag, and executing a
        // quarantined script directly can be blocked by Gatekeeper, while reading one as bash's input is not.
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [root.appendingPathComponent("ripperdoc").path] + args
        process.environment = environment
        process.currentDirectoryURL = root
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        return await withCheckedContinuation { continuation in
            let buffer = LineBuffer()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { return }
                for line in buffer.append(chunk) {
                    Task { @MainActor in onLine(line) }
                }
            }
            process.terminationHandler = { p in
                pipe.fileHandleForReading.readabilityHandler = nil
                let rest = pipe.fileHandleForReading.readDataToEndOfFile()
                let tail = buffer.append(rest).joined(separator: "\n") + "\n" + buffer.drain()
                Task { @MainActor in
                    for line in tail.split(separator: "\n", omittingEmptySubsequences: true) { onLine(String(line)) }
                    continuation.resume(returning: p.terminationStatus)
                }
            }
            do {
                try process.run()
            } catch {
                Task { @MainActor in
                    onLine("error could not start ripperdoc: \(error.localizedDescription)")
                    continuation.resume(returning: 126)
                }
            }
        }
    }
}

/// Splits a byte stream into lines. The pipe's handlers run on background queues, so access is locked.
private final class LineBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    /// Appends bytes and returns the complete lines they finished.
    func append(_ chunk: Data) -> [String] {
        lock.lock(); defer { lock.unlock() }
        data.append(chunk)
        var lines: [String] = []
        while let nl = data.firstIndex(of: 0x0A) {
            lines.append(String(decoding: data[data.startIndex..<nl], as: UTF8.self))
            data.removeSubrange(data.startIndex...nl)
        }
        return lines
    }

    /// The last, unterminated line.
    func drain() -> String {
        lock.lock(); defer { lock.unlock() }
        defer { data.removeAll() }
        return String(decoding: data, as: UTF8.self)
    }
}
