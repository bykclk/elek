import NetworkExtension
import os

/// DNS proxy provider. Step 1: parse the queried name, log it, and forward
/// every query to an upstream resolver over plain UDP/TCP. The block decision
/// (allowlist / blocklist / Binary Fuse) lands in step 3; DoH in step 4.
///
/// Fail-open everywhere: any error forwards or closes cleanly, never breaks
/// connectivity.
/// Blocklist loaded when the proxy starts and refreshed when the app rebuilds
/// it. nil => fail-open (forward everything). The app installs blocklist.bin into
/// the App Group container before enabling, so it exists by the time startProxy
/// runs.
var activeBlocklist: Blocklist?
private var activeBlocklistMTime: Date?
private let blocklistLog = Logger(subsystem: AppConstants.proxyBundleID, category: "blocklist")

/// Reload the blocklist if the App Group file changed since we last loaded it.
/// Cheap stat + compare; only re-mmaps on an actual update.
func loadBlocklistIfChanged() {
    guard let url = AppGroup.blocklistURL else { return }
    let mtime = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    if activeBlocklist != nil && mtime == activeBlocklistMTime { return }
    if let bl = Blocklist(url: url) {
        activeBlocklist = bl
        activeBlocklistMTime = mtime
        blocklistLog.info("blocklist (re)loaded")
    } else {
        blocklistLog.error("blocklist load failed (fail-open)")
    }
}

final class DNSProxyProvider: NEDNSProxyProvider {

    private let log = Logger(subsystem: AppConstants.proxyBundleID, category: "proxy")
    private var reloadTimer: DispatchSourceTimer?

    override func startProxy(options: [String: Any]? = nil,
                             completionHandler: @escaping (Error?) -> Void) {
        loadBlocklistIfChanged()
        log.info("startProxy blocklist=\(activeBlocklist == nil ? "MISSING (fail-open)" : "loaded", privacy: .public)")

        // Pick up on-device list updates without restarting the proxy.
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { loadBlocklistIfChanged() }
        timer.resume()
        reloadTimer = timer

        completionHandler(nil)
    }

    override func stopProxy(with reason: NEProviderStopReason,
                            completionHandler: @escaping () -> Void) {
        reloadTimer?.cancel()
        reloadTimer = nil
        log.info("stopProxy reason=\(reason.rawValue, privacy: .public)")
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        if let udp = flow as? NEAppProxyUDPFlow {
            log.info("handleNewFlow UDP")
            UDPForwarder(flow: udp, log: log).start()
            return true
        }
        if let tcp = flow as? NEAppProxyTCPFlow {
            log.info("handleNewFlow TCP")
            TCPForwarder(flow: tcp, log: log).start()
            return true
        }
        // Unknown flow type — let the system handle it directly.
        log.info("handleNewFlow UNKNOWN -> passthrough")
        return false
    }
}
