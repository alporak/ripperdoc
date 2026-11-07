import AppKit
import SwiftUI

@main
struct RipperdocApp: App {
    @StateObject private var model = AppModel()

    init() {
        // Run as a regular app (Dock icon, menu bar) also when started from `swift run`.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Ripperdoc") {
            ContentView()
                .environmentObject(model)
                .environmentObject(model.support)
                .frame(minWidth: 820, minHeight: 520)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .help) {
                Button("Support Ripperdoc…") { SupportPrompt.open() }
            }
        }
    }
}

enum Pane: String, CaseIterable, Identifiable {
    case status = "Status", frameworks = "Frameworks", mods = "Mods", log = "Log"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .status: "stethoscope"
        case .frameworks: "cpu"
        case .mods: "shippingbox"
        case .log: "text.alignleft"
        }
    }
}

/// View-local state. Plain ObservableObjects instead of @State: on the macOS 27 SDK @State is a macro whose plugin only ships
/// with Xcode, and this builds with the command line tools too.
final class Selection: ObservableObject {
    @Published var section: Pane? = .status
}

final class ModsUIState: ObservableObject {
    @Published var dropping = false
    @Published var picking = false
    @Published var expanded: Set<String> = []
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var support: SupportPrompt
    @StateObject private var selection = Selection()

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $selection.section) { s in
                Label(s.rawValue, systemImage: s.icon).tag(s)
            }
            .navigationSplitViewColumnWidth(170)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Button { SupportPrompt.open() } label: {
                        Label("Support Ripperdoc", systemImage: "cup.and.saucer")
                    }
                    .buttonStyle(.borderless)
                    .help("Buy me a coffee")
                    Text("Unofficial. Not affiliated with CD PROJEKT RED.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(8)
            }
        } detail: {
            VStack(spacing: 0) {
                if let busy = model.busy {
                    HStack { ProgressView().controlSize(.small); Text(busy).font(.callout); Spacer() }
                        .padding(.horizontal).padding(.vertical, 6).background(.bar)
                }
                if let error = model.lastError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(error).font(.callout).textSelection(.enabled)
                        Spacer()
                        Button("Dismiss") { model.lastError = nil }.buttonStyle(.borderless)
                    }
                    .padding(.horizontal).padding(.vertical, 6).background(.orange.opacity(0.12))
                }
                switch selection.section ?? .status {
                case .status: StatusView()
                case .frameworks: FrameworksView()
                case .mods: ModsView()
                case .log: LogView()
                }
            }
        }
        .sheet(isPresented: $support.isPresented) { SupportSheet(prompt: support) }
        .onAppear {
            // For screenshots and testing: RIPPERDOC_SHOW_SUPPORT=1 shows the support sheet once the window is up.
            if ProcessInfo.processInfo.environment["RIPPERDOC_SHOW_SUPPORT"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { support.isPresented = true }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.play()
                    selection.section = .log
                } label: {
                    Label(model.gameRunning ? "Running" : "Play", systemImage: model.gameRunning ? "gamecontroller.fill" : "play.fill")
                }
                .help("Start the modded copy of the game (Steam must be running)")
                .disabled(model.gameRunning || model.busy != nil || !model.hasCopy || !model.allInstalled)
            }
        }
    }
}

struct StatusView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                if model.checks.isEmpty {
                    HStack { ProgressView().controlSize(.small); Text("Checking…") }
                }
                ForEach(model.checks) { check in
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: check.ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(check.ok ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title)
                            if let hint = check.hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            } header: {
                Text(model.healthy ? "Everything is ready" : "Setup")
            }
            Section("Actions") {
                if !model.hasCopy {
                    action("Create the game copy", "Clones the Steam game instantly (APFS clone, no extra disk space). Steam's install is never changed.",
                           "square.on.square") { await model.setup() }
                }
                if model.hasCopy && !model.allInstalled {
                    action("Install all frameworks", "Downloads and verifies the releases, builds the source ports (a few minutes the first time).",
                           "square.and.arrow.down") { await model.installAll() }
                }
                if model.hasCopy {
                    action("Refresh after a game update", "Re-clones the game and keeps your mods and frameworks.",
                           "arrow.triangle.2.circlepath") { await model.refresh() }
                    HStack {
                        Button("Show game copy in Finder") { model.revealGame() }
                        Button("Open framework logs") { model.revealLogs() }
                        Button("Open game output logs") { model.revealPlayLogs() }
                        Spacer()
                        Button("Re-check") { Task { await model.doctor() } }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func action(_ title: String, _ detail: String, _ icon: String, _ run: @escaping () async -> Void) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Run") { Task { await run() } }.disabled(model.busy != nil || model.gameRunning)
        }
    }
}

struct FrameworksView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Table(model.components) {
            TableColumn("Framework") { c in
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).lineLimit(2)
                    if let url = URL(string: c.homepage) {
                        Link(c.homepage.replacingOccurrences(of: "https://github.com/", with: ""), destination: url).font(.caption)
                    }
                }
            }.width(min: 220, ideal: 280)
            TableColumn("Version") { c in Text(c.version).monospacedDigit() }.width(130)
            TableColumn("Installed") { c in
                if c.upToDate {
                    Label("Yes", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else if let v = c.installed {
                    Label(v, systemImage: "arrow.up.circle").foregroundStyle(.orange)
                } else {
                    Text("No").foregroundStyle(.secondary)
                }
            }.width(110)
            TableColumn("License") { c in Text(c.license).font(.caption).foregroundStyle(.secondary).lineLimit(3) }.width(min: 120, ideal: 160)
            TableColumn("") { c in
                Button(c.upToDate ? "Reinstall" : "Install") { Task { await model.install(c.id) } }
                    .disabled(model.busy != nil || model.gameRunning || !model.hasCopy)
            }.width(90)
        }
    }
}

struct ModsView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var ui = ModsUIState()

    var body: some View {
        VStack(spacing: 0) {
            List {
                if model.mods.isEmpty {
                    Text("No mods installed yet.").foregroundStyle(.secondary)
                }
                ForEach(model.mods) { mod in
                    DisclosureGroup(isExpanded: Binding(
                        get: { ui.expanded.contains(mod.name) },
                        set: { if $0 { ui.expanded.insert(mod.name) } else { ui.expanded.remove(mod.name) } })) {
                        ForEach(mod.files, id: \.self) { Text($0).font(.caption.monospaced()).foregroundStyle(.secondary) }
                    } label: {
                        HStack {
                            Label(mod.name, systemImage: "shippingbox")
                            Text("\(mod.files.count) files").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Remove", role: .destructive) { Task { await model.removeMod(mod.name) } }
                                .disabled(model.busy != nil || model.gameRunning)
                        }
                    }
                }
            }
            dropZone
        }
        .fileImporter(isPresented: $ui.picking, allowedContentTypes: [.zip, .data, .folder], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { install(urls) }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down").font(.title2)
            Text("Drop a mod here (.zip, .rar, .7z or folder, as downloaded for Windows)")
            Button("Choose…") { ui.picking = true }.disabled(model.busy != nil || model.gameRunning || !model.hasCopy)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            .foregroundStyle(ui.dropping ? Color.accentColor : .secondary))
        .padding()
        .onDrop(of: [.fileURL], isTargeted: $ui.dropping) { providers in
            for p in providers {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    if let url { Task { @MainActor in install([url]) } }
                }
            }
            return true
        }
    }

    private func install(_ urls: [URL]) {
        Task {
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                await model.addMod(url)
                if access { url.stopAccessingSecurityScopedResource() }
            }
        }
    }
}

struct LogView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(model.log.enumerated()), id: \.offset) { i, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .foregroundStyle(line.hasPrefix("$ ") ? Color.accentColor : line.hasPrefix("error") || line.hasPrefix("warn") ? .orange : .primary)
                            .textSelection(.enabled)
                            .id(i)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .onChange(of: model.log.count) { _, count in proxy.scrollTo(count - 1, anchor: .bottom) }
            .overlay {
                if model.log.isEmpty { Text("Command output appears here.").foregroundStyle(.secondary) }
            }
        }
    }
}
