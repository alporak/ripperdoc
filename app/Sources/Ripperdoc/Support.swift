import AppKit
import SwiftUI

/// The one gentle "please support this" prompt. Rules, so it never nags:
/// - only after something worked (a game session that ended normally, or a mod installed);
/// - at most once every 30 days, and at most 3 times in all;
/// - never again after "Buy me a coffee" or "Don't show again".
@MainActor
final class SupportPrompt: ObservableObject {
    static let url = URL(string: "https://buymeacoffee.com/alporak")!

    @Published var isPresented = false

    private let defaults = UserDefaults.standard
    private let interval: TimeInterval = 30 * 24 * 3600
    private let maxTimes = 3

    private var timesShown: Int {
        get { defaults.integer(forKey: "support.timesShown") }
        set { defaults.set(newValue, forKey: "support.timesShown") }
    }
    private var lastShown: Date? {
        get { defaults.object(forKey: "support.lastShown") as? Date }
        set { defaults.set(newValue, forKey: "support.lastShown") }
    }
    private var done: Bool {
        get { defaults.bool(forKey: "support.done") }
        set { defaults.set(newValue, forKey: "support.done") }
    }

    func considerAsking() {
        guard !done, !isPresented, timesShown < maxTimes else { return }
        if let last = lastShown, Date().timeIntervalSince(last) < interval { return }
        timesShown += 1
        lastShown = Date()
        isPresented = true
    }

    func donate() {
        done = true
        isPresented = false
        NSWorkspace.shared.open(Self.url)
    }

    func later() { isPresented = false }

    func never() {
        done = true
        isPresented = false
    }

    /// The always-available link (sidebar, Help menu); it never changes the prompt's schedule.
    static func open() { NSWorkspace.shared.open(url) }
}

struct SupportSheet: View {
    @ObservedObject var prompt: SupportPrompt

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 34))
                .foregroundStyle(.yellow)
            Text("Enjoying Ripperdoc?")
                .font(.title3.weight(.semibold))
            Text("A lot of work went into making these mod frameworks run on the Mac. If Ripperdoc is useful to you, I'd appreciate it if you give back.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
            HStack {
                Button("Don't show again") { prompt.never() }
                    .buttonStyle(.borderless)
                Spacer()
                Button("Maybe later") { prompt.later() }
                    .keyboardShortcut(.cancelAction)
                Button("Buy me a coffee") { prompt.donate() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 420)
    }
}
