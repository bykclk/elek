import NetworkExtension
import os

/// DNS proxy provider. Step 1: parse the queried name, log it, and forward
/// every query to an upstream resolver over plain UDP/TCP. The block decision
/// (allowlist / blocklist / Binary Fuse) lands in step 3; DoH in step 4.
///
/// Fail-open everywhere: any error forwards or closes cleanly, never breaks
/// connectivity.
/// Blocklist loaded when the proxy starts. nil => fail-open (forward everything).
/// The app installs blocklist.bin into the App Group container before enabling,
/// so it exists by the time startProxy runs.
var activeBlocklist: Blocklist?

final class DNSProxyProvider: NEDNSProxyProvider {

    private let log = Logger(subsystem: AppConstants.proxyBundleID, category: "proxy")

    override func startProxy(options: [String: Any]? = nil,
                             completionHandler: @escaping (Error?) -> Void) {
        activeBlocklist = AppGroup.blocklistURL.flatMap(Blocklist.init(url:))
        log.info("startProxy blocklist=\(activeBlocklist == nil ? "MISSING (fail-open)" : "loaded", privacy: .public)")
        completionHandler(nil)
    }

    override func stopProxy(with reason: NEProviderStopReason,
                            completionHandler: @escaping () -> Void) {
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
