import NetworkExtension
import os

/// Blocklist loaded when the tunnel starts and refreshed when the app rebuilds
/// it. nil => fail-open (forward everything).
var activeBlocklist: Blocklist?
private var activeBlocklistMTime: Date?
private let blocklistLog = Logger(subsystem: AppConstants.proxyBundleID, category: "blocklist")

/// Reload the blocklist if the App Group file changed since we last loaded it.
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

/// DNS-only packet tunnel. The system routes ONLY the virtual resolver
/// (10.7.0.1/32) into this tunnel and uses it as the DNS server for every
/// query; all other traffic keeps flowing over the normal interfaces. Blocked
/// names are answered locally with NXDOMAIN; everything else resolves over DoH.
///
/// This replaces the earlier NEDNSProxyProvider: per Apple TN3134, DNS proxy
/// providers only work on supervised/managed devices, while packet tunnels are
/// available to ordinary App Store users.
final class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = Logger(subsystem: AppConstants.proxyBundleID, category: "tunnel")
    private var reloadTimer: DispatchSourceTimer?

    override func startTunnel(options: [String: NSObject]? = nil,
                              completionHandler: @escaping (Error?) -> Void) {
        loadBlocklistIfChanged()
        log.info("startTunnel blocklist=\(activeBlocklist == nil ? "MISSING (fail-open)" : "loaded", privacy: .public)")

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let ipv4 = NEIPv4Settings(addresses: [AppConstants.tunnelClientIP],
                                  subnetMasks: ["255.255.255.255"])
        // Route ONLY the virtual resolver into the tunnel — this is what keeps
        // it a DNS filter rather than a real VPN.
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: AppConstants.dnsServerIP,
                                           subnetMask: "255.255.255.255")]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: [AppConstants.dnsServerIP])
        dns.matchDomains = [""]   // default resolver for all domains
        settings.dnsSettings = dns
        settings.mtu = 1500

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else { return }
            if let error {
                self.log.error("setTunnelNetworkSettings failed: \(error.localizedDescription, privacy: .public)")
                completionHandler(error)
                return
            }

            // Pick up on-device blocklist updates without restarting the tunnel.
            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
            timer.schedule(deadline: .now() + 60, repeating: 60)
            timer.setEventHandler { loadBlocklistIfChanged() }
            timer.resume()
            self.reloadTimer = timer

            self.readLoop()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        reloadTimer?.cancel()
        reloadTimer = nil
        log.info("stopTunnel reason=\(reason.rawValue, privacy: .public)")
        completionHandler()
    }

    // MARK: - Packet loop

    private func readLoop() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self else { return }
            for (packet, proto) in zip(packets, protocols) where proto.int32Value == AF_INET {
                self.handle(packet)
            }
            self.readLoop()
        }
    }

    private func handle(_ packet: Data) {
        // Only DNS datagrams for the virtual resolver are expected here;
        // anything else is dropped (fail-open at the routing level — other
        // traffic never enters the tunnel at all).
        guard let request = IPPacket.parseUDP(packet),
              request.destinationPort == 53 else { return }

        let query = request.payload
        let qname = DNSMessage.firstQuestionName(query)

        if let qname, shouldBlock(qname) {
            log.info("BLOCK \(qname, privacy: .public)")
            BlockCounter.increment()
            reply(DNSMessage.nxdomain(for: query), to: request)
            return
        }

        log.info("FWD \(qname ?? "<unparsed>", privacy: .public)")
        resolveUpstream(query, log: log) { [weak self] answer in
            guard let self, let answer else { return }   // both DoH and fallback failed: drop
            self.reply(answer, to: request)
        }
    }

    private func reply(_ payload: Data, to request: UDPPacket) {
        let packet = IPPacket.buildUDPReply(payload: payload, to: request)
        packetFlow.writePackets([packet], withProtocols: [NSNumber(value: AF_INET)])
    }
}
