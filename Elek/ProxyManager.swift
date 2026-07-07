import Foundation
import NetworkExtension
import os

/// Drives the DNS-filter tunnel configuration from the app side.
///
/// Calling `enable()` for the first time triggers the iOS permission prompt
/// ("Elek Would Like to Add VPN Configurations"). Approving it installs the
/// configuration and starts the `ElekProxy` packet-tunnel extension, which
/// filters DNS entirely on-device.
///
/// Every failure path ends in `.error(message)` so the UI can always show the
/// user something — a tap must never look like a dead button.
@MainActor
final class ProxyManager: ObservableObject {
    enum State: Equatable {
        case unknown
        case off
        case on
        case busy
        case error(String)
    }

    private enum Intent { case none, enabling, disabling }

    @Published private(set) var state: State = .unknown

    private var manager: NETunnelProviderManager?
    private var intent: Intent = .none
    private let log = Logger(subsystem: "com.bykclk.elek", category: "ProxyManager")
    private var watchdog: Task<Void, Never>?
    private var statusObserver: NSObjectProtocol?

    var isOn: Bool { state == .on }

    /// The message to show when protection couldn't be turned on, else nil.
    var errorMessage: String? {
        if case .error(let message) = state { return message }
        return nil
    }

    init() {
        // Track the tunnel's real state (covers Settings-app toggles, on-demand
        // restarts, and the async completion of our own start/stop).
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.syncFromStatus() }
        }
    }

    deinit {
        if let statusObserver { NotificationCenter.default.removeObserver(statusObserver) }
    }

    /// Load the existing configuration (if any). A load failure is treated as
    /// "off" so the app never opens straight into an alert — tapping enable
    /// surfaces any real problem.
    func load() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = managers.first
            if manager == nil {
                state = .off
            } else {
                syncFromStatus()
            }
            log.info("loaded, managers=\(managers.count, privacy: .public)")
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
        intent = .enabling
        state = .busy
        startWatchdog()
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            let mgr = managers.first ?? NETunnelProviderManager()

            let proto = (mgr.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
            proto.providerBundleIdentifier = AppConstants.proxyBundleID
            proto.serverAddress = "on-device"   // cosmetic; there is no server
            mgr.protocolConfiguration = proto
            mgr.localizedDescription = "Elek"
            mgr.isEnabled = true
            // Reconnect automatically (reboots, network changes) while enabled.
            mgr.onDemandRules = [NEOnDemandRuleConnect()]
            mgr.isOnDemandEnabled = true

            try await mgr.saveToPreferences()   // first time: VPN permission prompt
            try await mgr.loadFromPreferences()
            manager = mgr

            try mgr.connection.startVPNTunnel()
            log.info("tunnel start requested")
            syncFromStatus()   // .connecting keeps .busy; observer flips to .on
        } catch {
            let ns = error as NSError
            intent = .none
            log.error("enable failed: domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public) desc=\(ns.localizedDescription, privacy: .public)")
            state = .error("Protection couldn’t be turned on. \(error.localizedDescription) (\(ns.domain) \(ns.code))")
        }
    }

    func disable() async {
        guard state != .busy else { return }
        intent = .disabling
        state = .busy
        startWatchdog()
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            guard let mgr = managers.first else {
                intent = .none
                state = .off
                return
            }
            manager = mgr
            mgr.isOnDemandEnabled = false
            try await mgr.saveToPreferences()
            mgr.connection.stopVPNTunnel()
            log.info("tunnel stop requested")
            syncFromStatus()   // .disconnecting keeps .busy; observer flips to .off
        } catch {
            let ns = error as NSError
            intent = .none
            log.error("disable failed: domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public) desc=\(ns.localizedDescription, privacy: .public)")
            state = .error("Couldn’t turn protection off. \(error.localizedDescription)")
        }
    }

    /// Dismiss an error back to a usable state (called when the alert closes).
    func clearError() {
        if case .error = state { state = .off }
    }

    // MARK: - Status tracking

    private func syncFromStatus() {
        guard let connection = manager?.connection else { return }
        switch connection.status {
        case .connected:
            intent = .none
            state = .on
        case .connecting, .reasserting, .disconnecting:
            state = .busy
        case .disconnected, .invalid:
            switch intent {
            case .enabling:
                // Start was requested but the tunnel came down: a real failure,
                // never a silent no-op.
                intent = .none
                state = .error("Protection couldn’t start. Please try again.")
            default:
                intent = .none
                if case .error = state { break }   // keep the message visible
                state = .off
            }
        @unknown default:
            break
        }
    }

    // MARK: - Busy watchdog

    /// Guarantees the button can never be permanently stuck disabled: if we're
    /// still `.busy` after 90s, re-sync from the system and surface an error if
    /// nothing resolved. 90s is long enough not to interrupt a legitimately
    /// on-screen permission prompt.
    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(90))
            guard let self, !Task.isCancelled else { return }
            if self.state == .busy {
                await self.load()
                if self.state == .busy {
                    self.intent = .none
                    self.manager?.connection.stopVPNTunnel()
                    self.state = .error("This is taking longer than expected. Please try again.")
                }
            }
        }
    }
}
