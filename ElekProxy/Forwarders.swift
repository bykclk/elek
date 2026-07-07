import Foundation
import Network
import os

/// Plain-UDP fallback resolver, used only when DoH fails (keeps connectivity
/// alive even if the encrypted path is blocked by the network). Reached by IP
/// literal, and 1.1.1.1 is not routed into the tunnel, so there is no loop.
enum Upstream {
    static let host = Network.NWEndpoint.Host("1.1.1.1")
    static let port = Network.NWEndpoint.Port(integerLiteral: 53)
    static let queue = DispatchQueue(label: "com.bykclk.elek.dnsproxy.upstream", attributes: .concurrent)
}

/// DNS-over-HTTPS upstream (RFC 8484). We POST the raw DNS query to Cloudflare
/// by IP literal — https://1.1.1.1/dns-query — whose TLS cert includes 1.1.1.1
/// as an IP SAN. Using the IP avoids a chicken-and-egg DNS lookup that would
/// otherwise loop back through this very tunnel.
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
