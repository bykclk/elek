import NetworkExtension
import Network
import os

/// Plain-UDP fallback resolver, used only when DoH fails (keeps connectivity
/// alive even if the encrypted path is blocked by the network).
enum Upstream {
    static let host = Network.NWEndpoint.Host("1.1.1.1")
    static let port = Network.NWEndpoint.Port(integerLiteral: 53)
    static let queue = DispatchQueue(label: "com.elek.app.dnsproxy.upstream", attributes: .concurrent)
}

/// DNS-over-HTTPS upstream (RFC 8484). We POST the raw DNS query to Cloudflare
/// by IP literal — https://1.1.1.1/dns-query — whose TLS cert includes 1.1.1.1
/// as an IP SAN. Using the IP avoids a chicken-and-egg DNS lookup that would
/// otherwise loop back through this very proxy.
enum DoH {
    static let endpoint = URL(string: "https://1.1.1.1/dns-query")!

    static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 4
        cfg.waitsForConnectivity = false
        cfg.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: cfg)
    }()

    static func resolve(_ query: Data, log: Logger, completion: @escaping (Data?) -> Void) {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        req.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        req.httpBody = query
        session.dataTask(with: req) { data, resp, err in
            if let err {
                log.error("doh: \(err.localizedDescription, privacy: .public)")
                completion(nil); return
            }
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let data, !data.isEmpty else {
                log.error("doh: bad response")
                completion(nil); return
            }
            completion(data)
        }.resume()
    }
}

/// Resolve an allowed query: try DoH first; on any failure fall back to plain
/// UDP so connectivity is preserved. `completion(nil)` only if both fail.
func resolveUpstream(_ query: Data, log: Logger, completion: @escaping (Data?) -> Void) {
    DoH.resolve(query, log: log) { data in
        if let data { completion(data); return }
        log.error("doh failed -> plain UDP fallback")
        plainUDPForward(query, log: log, completion: completion)
    }
}

/// One-shot plain UDP query to the fallback resolver.
func plainUDPForward(_ query: Data, log: Logger, completion: @escaping (Data?) -> Void) {
    let conn = NWConnection(host: Upstream.host, port: Upstream.port, using: .udp)
    var finished = false
    let finish: (Data?) -> Void = { data in
        if finished { return }
        finished = true
        conn.cancel()
        completion(data)
    }
    conn.stateUpdateHandler = { state in
        switch state {
        case .ready:
            conn.send(content: query, completion: .contentProcessed { err in
                if let err {
                    log.error("udp fallback send: \(err.localizedDescription, privacy: .public)")
                    finish(nil); return
                }
                conn.receiveMessage { data, _, _, _ in finish(data) }
            })
        case .failed(let err):
            log.error("udp fallback failed: \(err.localizedDescription, privacy: .public)")
            finish(nil)
        case .waiting(let err):
            log.error("udp fallback waiting: \(err.localizedDescription, privacy: .public)")
            finish(nil)
        default:
            break
        }
    }
    conn.start(queue: Upstream.queue)
}

/// Block decision. Resolution order (user lists optional in v1 — stubbed empty):
/// allowlist -> user blocklist -> Binary Fuse (full qname then each parent
/// suffix). Fail-open: no blocklist loaded => forward.
@inline(__always)
func shouldBlock(_ qname: String) -> Bool {
    return activeBlocklist?.blocks(qname) ?? false
}

// MARK: - UDP

/// Forwards a UDP DNS flow. Each datagram is an independent query; allowed
/// queries go upstream (DoH), blocked ones are answered with NXDOMAIN locally.
final class UDPForwarder {
    private let flow: NEAppProxyUDPFlow
    private let log: Logger
    /// Keeps the forwarder alive for the lifetime of the flow. Async callbacks
    /// use [weak self]; without this the instance would deallocate as soon as
    /// handleNewFlow returns and the flow would never be read. Cleared in close().
    private var selfRetain: UDPForwarder?

    init(flow: NEAppProxyUDPFlow, log: Logger) {
        self.flow = flow
        self.log = log
    }

    func start() {
        selfRetain = self
        flow.open(withLocalEndpoint: nil) { [weak self] error in
            guard let self else { return }
            if let error {
                self.log.error("udp open: \(error.localizedDescription, privacy: .public)")
                self.close(error)
                return
            }
            self.readLoop()
        }
    }

    private func readLoop() {
        flow.readDatagrams { [weak self] datagrams, endpoints, error in
            guard let self else { return }
            if let error {
                self.log.error("udp read: \(error.localizedDescription, privacy: .public)")
                self.close(error)
                return
            }
            guard let datagrams, let endpoints, !datagrams.isEmpty else {
                self.close(nil)   // flow closed
                return
            }
            // `endpoint` keeps its inferred type (the deprecated NetworkExtension
            // NWEndpoint, ambiguous with Network.NWEndpoint once both modules are
            // imported). We capture it in a write-back closure rather than naming it.
            for (query, endpoint) in zip(datagrams, endpoints) {
                self.handle(query: query) { [weak self] answer in
                    self?.flow.writeDatagrams([answer], sentBy: [endpoint]) { writeErr in
                        if let writeErr {
                            self?.log.error("udp writeback: \(writeErr.localizedDescription, privacy: .public)")
                        }
                    }
                }
            }
            self.readLoop()
        }
    }

    private func handle(query: Data, write: @escaping (Data) -> Void) {
        let qname = DNSMessage.firstQuestionName(query)

        if let qname, shouldBlock(qname) {
            log.info("BLOCK \(qname, privacy: .public)")
            BlockCounter.increment()
            write(DNSMessage.nxdomain(for: query))
            return
        }

        log.info("FWD \(qname ?? "<unparsed>", privacy: .public)")
        resolveUpstream(query, log: log) { answer in
            guard let answer else { return }   // both DoH and fallback failed: drop
            write(answer)
        }
    }

    private func close(_ error: Error?) {
        flow.closeReadWithError(error)
        flow.closeWriteWithError(error)
        selfRetain = nil
    }
}

// MARK: - TCP

/// Forwards a TCP DNS flow. DNS-over-TCP frames each message with a 2-byte
/// big-endian length prefix; we de-frame, apply the same block/forward logic as
/// UDP (NXDOMAIN locally or DoH upstream), and re-frame the response.
final class TCPForwarder {
    private let flow: NEAppProxyTCPFlow
    private let log: Logger
    private var selfRetain: TCPForwarder?
    private var buffer = Data()

    init(flow: NEAppProxyTCPFlow, log: Logger) {
        self.flow = flow
        self.log = log
    }

    func start() {
        selfRetain = self
        flow.open(withLocalEndpoint: nil) { [weak self] error in
            guard let self else { return }
            if let error {
                self.log.error("tcp open: \(error.localizedDescription, privacy: .public)")
                self.close(error)
                return
            }
            self.readLoop()
        }
    }

    private func readLoop() {
        flow.readData { [weak self] data, error in
            guard let self else { return }
            if let error { self.close(error); return }
            guard let data, !data.isEmpty else { self.close(nil); return }  // closed
            self.buffer.append(data)
            self.drain()
            self.readLoop()
        }
    }

    /// Extract every complete length-prefixed message currently buffered.
    private func drain() {
        while buffer.count >= 2 {
            let base = buffer.startIndex
            let len = Int(buffer[base]) << 8 | Int(buffer[base + 1])
            guard buffer.count >= 2 + len else { break }
            let msg = buffer.subdata(in: (base + 2) ..< (base + 2 + len))
            buffer.removeSubrange(base ..< (base + 2 + len))
            handle(query: msg)
        }
    }

    private func handle(query: Data) {
        let qname = DNSMessage.firstQuestionName(query)

        if let qname, shouldBlock(qname) {
            log.info("BLOCK \(qname, privacy: .public) (tcp)")
            BlockCounter.increment()
            respond(DNSMessage.nxdomain(for: query))
            return
        }

        log.info("FWD \(qname ?? "<unparsed>", privacy: .public) (tcp)")
        resolveUpstream(query, log: log) { [weak self] answer in
            guard let self, let answer else { return }
            self.respond(answer)
        }
    }

    /// Write a DNS message back to the flow with its 2-byte length prefix.
    private func respond(_ message: Data) {
        var framed = Data(capacity: 2 + message.count)
        framed.append(UInt8(truncatingIfNeeded: message.count >> 8))
        framed.append(UInt8(truncatingIfNeeded: message.count))
        framed.append(message)
        flow.write(framed) { [weak self] err in
            if let err {
                self?.log.error("tcp writeback: \(err.localizedDescription, privacy: .public)")
            }
        }
    }

    private func close(_ error: Error?) {
        flow.closeReadWithError(error)
        flow.closeWriteWithError(error)
        selfRetain = nil
    }
}
