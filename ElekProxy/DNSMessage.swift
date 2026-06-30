import Foundation

/// Minimal DNS wire-format helpers. Only what the proxy needs: pull the first
/// question's QNAME out of a query, and synthesize an NXDOMAIN answer.
enum DNSMessage {

    /// Returns the first question's domain name, lowercased, without a trailing
    /// dot (e.g. "ads.example.com"). Returns nil if the message can't be parsed
    /// — callers treat nil as "forward" (fail-open).
    static func firstQuestionName(_ data: Data) -> String? {
        let b = [UInt8](data)
        guard b.count > 12 else { return nil }
        let qdcount = (Int(b[4]) << 8) | Int(b[5])
        guard qdcount >= 1 else { return nil }

        var idx = 12
        var labels: [String] = []
        while idx < b.count {
            let len = Int(b[idx])
            if len == 0 { break }                  // end of name
            if len & 0xC0 != 0 { return nil }      // compression pointer: unexpected in a question
            idx += 1
            guard idx + len <= b.count else { return nil }
            guard let label = String(bytes: b[idx..<idx + len], encoding: .utf8) else { return nil }
            labels.append(label)
            idx += len
        }
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: ".").lowercased()
    }

    /// Build an NXDOMAIN response for the given query: copy the ID + question,
    /// set QR=1, RCODE=3 (NXDOMAIN), zero the answer/authority/additional
    /// counts. Used to sinkhole blocked domains (step 3).
    static func nxdomain(for query: Data) -> Data {
        var b = [UInt8](query)
        guard b.count >= 12 else { return query }
        // Flags: QR=1, keep Opcode/RD from the query, RA=1, RCODE=3.
        let rd = b[2] & 0x01
        b[2] = 0x80 | (b[2] & 0x78) | rd   // QR=1, preserve opcode, preserve RD
        b[3] = 0x80 | 0x03                 // RA=1, RCODE=3 (NXDOMAIN)
        // ANCOUNT / NSCOUNT / ARCOUNT = 0; keep QDCOUNT as-is.
        b[6] = 0; b[7] = 0
        b[8] = 0; b[9] = 0
        b[10] = 0; b[11] = 0
        return Data(b)
    }
}
