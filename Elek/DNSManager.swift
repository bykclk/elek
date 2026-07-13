import Foundation
import NetworkExtension
import os

/// Drives the system-wide encrypted-DNS configuration from the app side.
///
/// Elek does no filtering itself: it installs a DNS-over-HTTPS configuration
/// (`NEDNSSettingsManager`) that points the whole system at our resolver, which
/// blocks ads/trackers and forwards everything else. No Network Extension, no
/// VPN — this is the App Store–supported path for system-wide DNS.
///
/// Important iOS behavior: `saveToPreferences()` *installs* the configuration
/// but does **not** activate it. `isEnabled` is read-only; the user must switch
/// Elek on in Settings › General › VPN & Device Management › DNS. So enabling is
/// a two-step flow — install here, then guide the user to Settings — and we read
/// `isEnabled` back to reflect the real state.
@MainActor
final class DNSManager: ObservableObject {
    enum State: Equatable {
        case unknown
        case off             // nothing installed
        case needsActivation // installed, but the user hasn't switched it on in Settings
        case on              // installed AND enabled
        case busy
        case error(String)
    }

    @Published private(set) var state: State = .unknown

    private let manager = NEDNSSettingsManager.shared()
    private let log = Logger(subsystem: "com.bykclk.elek", category: "DNSManager")

    // Screenshot support: `ELEK_UI_STATE=on|pending|off` forces a fixed UI state
    // (the active state can't occur in the Simulator). Debug-only — never ships.
    private var screenshotMode = false

    init() {
        #if DEBUG
        if let s = ProcessInfo.processInfo.environment["ELEK_UI_STATE"] {
            screenshotMode = true
            switch s {
            case "on": state = .on
            case "pending": state = .needsActivation
            default: state = .off
            }
        }
        #endif
    }

    var isOn: Bool { state == .on }

    var errorMessage: String? {
        if case .error(let m) = state { return m }
        return nil
    }

    /// Re-read the system state. Called on launch and whenever the app returns
    /// to the foreground (e.g. after the user toggles Elek in Settings).
    func load() async {
        if screenshotMode { return }   // keep the forced screenshot state
        do {
            try await manager.loadFromPreferences()
            state = deriveState()
            log.info("loaded, state enabled=\(self.manager.isEnabled, privacy: .public) installed=\(self.manager.dnsSettings != nil, privacy: .public)")
        } catch {
            log.error("load failed: \(error.localizedDescription, privacy: .public)")
            state = .off
        }
    }

    func toggle() async {
        switch state {
        case .on, .needsActivation: await disable()
        default:                    await enable()
        }
    }

    /// Install (or refresh) the DoH configuration. It becomes active only once
    /// the user enables it in Settings, so we land in `.needsActivation` unless
    /// it was already enabled.
    func enable() async {
        guard state != .busy else { return }
        state = .busy
        do {
            try await manager.loadFromPreferences()

            guard let url = URL(string: AppConstants.dohURL) else {
                state = .error("The resolver address is invalid.")
                return
            }
            let doh = NEDNSOverHTTPSSettings(servers: [])
            doh.serverURL = url
            // matchDomains left unset → applies to every domain (system-wide).
            manager.dnsSettings = doh
            manager.localizedDescription = AppConstants.configDescription
            // Reconnect automatically on every network.
            manager.onDemandRules = [NEOnDemandRuleConnect()]

            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()   // refresh isEnabled
            state = deriveState()
            log.info("config installed, state=\(String(describing: self.state), privacy: .public)")
        } catch {
            let ns = error as NSError
            log.error("enable failed: domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public) desc=\(ns.localizedDescription, privacy: .public)")
            state = .error("Couldn’t install the DNS configuration. \(error.localizedDescription)")
        }
    }

    /// Remove the configuration entirely (the honest "off": since `isEnabled`
    /// can't be set from code, uninstalling is how the app turns protection off).
    func disable() async {
        guard state != .busy else { return }
        state = .busy
        do {
            try await manager.loadFromPreferences()
            try await manager.removeFromPreferences()
            state = .off
            log.info("config removed")
        } catch {
            let ns = error as NSError
            log.error("disable failed: domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)")
            state = .error("Couldn’t remove the DNS configuration. \(error.localizedDescription)")
        }
    }

    func clearError() {
        if case .error = state { state = .off }
    }

    private func deriveState() -> State {
        if manager.isEnabled { return .on }
        return manager.dnsSettings != nil ? .needsActivation : .off
    }
}
