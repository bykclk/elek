import SwiftUI

/// Polls the shared "blocked today" counter from the App Group while the app is
/// foregrounded. Cross-process KVO on UserDefaults isn't reliable, so a 1s poll
/// keeps the displayed number live without the extension having to notify us.
@MainActor
final class CounterStore: ObservableObject {
    @Published private(set) var count: Int = 0

    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        count = BlockCounter.today()
    }
}
