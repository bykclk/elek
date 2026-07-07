import Foundation
import NetworkExtension
import os

/// Drives the system DNS proxy configuration from the app side.
///
/// Calling `enable()` for the first time triggers the iOS permission prompt
/// ("Elek Would Like to Add Proxy Configurations"). Approving it installs the
/// configuration and starts the `ElekProxy` extension.
///
/// Every failure path (throwing OR the silent "saved but not enabled" case) ends
/// in `.error(message)` so the UI can always show the user something — a tap must
/// never look like a dead button.
@MainActor
final class ProxyManager: ObservableObject {
    enum State: Equatable {
        case unknown
        case off
        case on
        case busy
        case error(String)
    }

    @Published private(set) var state: State = .unknown

    private let manager = NEDNSProxyManager.shared()
    private let log = Logger(subsystem: "com.bykclk.elek", category: "ProxyManager")
    private var watchdog: Task<Void, Never>?

    var isOn: Bool { state == .on }

    /// The message to show when protection couldn't be turned on, else nil.
    var errorMessage: String? {
        if case .error(let message) = state { return message }
        return nil
    }

    /// Load the existing configuration (if any). A load failure is treated as
    /// "off" (not an error) so the app never opens showing an alert — the user
    /// can just tap to enable, which surfaces any real problem.
    func load() async {
        do {
            try await manager.loadFromPreferences()
            state = manager.isEnabled ? .on : .off
            log.info("loaded, enabled=\(self.manager.isEnabled, privacy: .public)")
        } catch {
            log.error("load failed: \(error.localizedDescription, privacy: .public)")
            state = .off
        }
    }

    func toggle() async {
        switch state {
        case .on: await disable()
        default:  await enable()
        }
    }

    func enable() async {
        guard state != .busy else { return }
        state = .busy
        startWatchdog()
        defer { stopWatchdog() }
        do {
            try await manager.loadFromPreferences()

            let proto = NEDNSProxyProviderProtocol()
            proto.providerBundleIdentifier = AppConstants.proxyBundleID
            proto.providerConfiguration = [:]

            manager.providerProtocol = proto
            manager.localizedDescription = "Elek"
            manager.isEnabled = true

            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()

            if manager.isEnabled {
                state = .on
                log.info("enabled")
            } else {
                // Saved without throwing but not enabled — e.g. the permission
                // prompt was dismissed. Don't fall silently back to .off.
                log.error("enable: saved but not enabled")
                state = .error("Protection couldn’t be turned on. When iOS asks, please allow Elek to add its proxy configuration.")
            }
        } catch {
            log.error("enable failed: \(error.localizedDescription, privacy: .public)")
            state = .error("Protection couldn’t be turned on. \(error.localizedDescription)")
        }
    }

    func disable() async {
        guard state != .busy else { return }
        state = .busy
        startWatchdog()
        defer { stopWatchdog() }
        do {
            try await manager.loadFromPreferences()
            manager.isEnabled = false
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            state = manager.isEnabled ? .on : .off
            log.info("disabled")
        } catch {
            log.error("disable failed: \(error.localizedDescription, privacy: .public)")
            state = .error("Couldn’t turn protection off. \(error.localizedDescription)")
        }
    }

    /// Dismiss an error back to a usable state (called when the alert is closed).
    func clearError() {
        if case .error = state { state = .off }
    }

    // MARK: - Busy watchdog

    /// Guarantees the button can never be permanently stuck disabled: if we're
    /// still `.busy` after 90s (a genuine subsystem hang), re-sync from the
    /// system. 90s is long enough not to interrupt a legitimately on-screen
    /// permission prompt.
    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(90))
            guard let self, !Task.isCancelled else { return }
            if self.state == .busy { await self.load() }
        }
    }

    private func stopWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }
}
