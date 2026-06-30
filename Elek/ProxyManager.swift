import Foundation
import NetworkExtension
import os

/// Drives the system DNS proxy configuration from the app side.
///
/// Calling `enable()` for the first time triggers the iOS permission prompt
/// ("Elek Would Like to Add Proxy Configurations"). Approving it installs the
/// configuration and starts the `ElekProxy` extension.
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

    var isOn: Bool { state == .on }

    /// Load the existing configuration (if any) from the system preferences.
    func load() async {
        do {
            try await manager.loadFromPreferences()
            state = manager.isEnabled ? .on : .off
            log.info("loaded, enabled=\(self.manager.isEnabled, privacy: .public)")
        } catch {
            state = .error(error.localizedDescription)
            log.error("load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Toggle protection on/off and persist the change (prompts on first use).
    func toggle() async {
        switch state {
        case .on:   await disable()
        default:    await enable()
        }
    }

    func enable() async {
        state = .busy
        do {
            try await manager.loadFromPreferences()

            let proto = NEDNSProxyProviderProtocol()
            proto.providerBundleIdentifier = AppConstants.proxyBundleID
            // Reserved for passing config to the extension (upstream, etc.).
            proto.providerConfiguration = [:]

            manager.providerProtocol = proto
            manager.localizedDescription = "Elek"
            manager.isEnabled = true

            try await manager.saveToPreferences()
            // Re-load so isEnabled reflects the saved state.
            try await manager.loadFromPreferences()
            state = manager.isEnabled ? .on : .off
            log.info("enabled")
        } catch {
            state = .error(error.localizedDescription)
            log.error("enable failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disable() async {
        state = .busy
        do {
            try await manager.loadFromPreferences()
            manager.isEnabled = false
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            state = manager.isEnabled ? .on : .off
            log.info("disabled")
        } catch {
            state = .error(error.localizedDescription)
            log.error("disable failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
