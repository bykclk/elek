import Foundation

/// One parsed UDP datagram from the tunnel.
struct UDPPacket {
    var sourceIP: [UInt8]        // 4 bytes
    var destinationIP: [UInt8]   // 4 bytes
    var sourcePort: UInt16
    var destinationPort: UInt16
    var payload: Data
}

/// Minimal IPv4/UDP codec for the DNS-only packet tunnel: parse inbound
/// datagrams headed for the virtual resolver, and build the mirrored reply
/// packets. No fragmentation support (DNS queries are tiny; replies carry DF),
/// no IPv6 (the tunnel only routes the IPv4 virtual resolver).
enum IPPacket {

    /// Parse an IPv4 UDP packet. Returns nil for anything else — the caller
    /// simply drops it (only the resolver /32 is routed here anyway).
    static func parseUDP(_ data: Data) -> UDPPacket? {
        let b = [UInt8](data)
        guard b.count >= 28 else { return nil }               // 20 IP + 8 UDP
        guard b[0] >> 4 == 4 else { return nil }              // IPv4
        let ihl = Int(b[0] & 0x0F) * 4
        guard ihl >= 20, b.count >= ihl + 8 else { return nil }
        guard b[9] == 17 else { return nil }                  // UDP
        let fragmentOffset = (UInt16(b[6] & 0x1F) << 8) | UInt16(b[7])
        let moreFragments = (b[6] & 0x20) != 0
        guard fragmentOffset == 0, !moreFragments else { return nil }

        let srcPort = UInt16(b[ihl]) << 8 | UInt16(b[ihl + 1])
        let dstPort = UInt16(b[ihl + 2]) << 8 | UInt16(b[ihl + 3])
        let udpLength = Int(UInt16(b[ihl + 4]) << 8 | UInt16(b[ihl + 5]))
        guard udpLength >= 8, ihl + udpLength <= b.count else { return nil }

        return UDPPacket(sourceIP: Array(b[12..<16]),
                         destinationIP: Array(b[16..<20]),
                         sourcePort: srcPort,
                         destinationPort: dstPort,
                         payload: Data(b[(ihl + 8)..<(ihl + udpLength)]))
    }

    /// Build a full IPv4+UDP packet.
    static func buildUDP(sourceIP: [UInt8], destinationIP: [UInt8],
                         sourcePort: UInt16, destinationPort: UInt16,
                         payload: Data) -> Data {
        let udpLength = 8 + payload.count
        let totalLength = 20 + udpLength
        var b = [UInt8](repeating: 0, count: totalLength)

        // IPv4 header
        b[0] = 0x45                                   // version 4, IHL 5
        b[2] = UInt8(totalLength >> 8)
        b[3] = UInt8(totalLength & 0xFF)
        b[6] = 0x40                                   // flags: DF
        b[8] = 64                                     // TTL
        b[9] = 17                                     // protocol: UDP
        b.replaceSubrange(12..<16, with: sourceIP)
        b.replaceSubrange(16..<20, with: destinationIP)
        let ipSum = checksum(Array(b[0..<20]))
        b[10] = UInt8(ipSum >> 8)
        b[11] = UInt8(ipSum & 0xFF)

        // UDP header + payload
        b[20] = UInt8(sourcePort >> 8);      b[21] = UInt8(sourcePort & 0xFF)
        b[22] = UInt8(destinationPort >> 8); b[23] = UInt8(destinationPort & 0xFF)
        b[24] = UInt8(udpLength >> 8);       b[25] = UInt8(udpLength & 0xFF)
        b.replaceSubrange(28..<totalLength, with: payload)

        // UDP checksum over pseudo-header + UDP segment
        var pseudo = [UInt8]()
        pseudo.reserveCapacity(12 + udpLength)
        pseudo.append(contentsOf: sourceIP)
        pseudo.append(contentsOf: destinationIP)
        pseudo.append(contentsOf: [0, 17, UInt8(udpLength >> 8), UInt8(udpLength & 0xFF)])
        pseudo.append(contentsOf: b[20...])
        var udpSum = checksum(pseudo)
        if udpSum == 0 { udpSum = 0xFFFF }            // RFC 768: 0 is "no checksum"
        b[26] = UInt8(udpSum >> 8)
        b[27] = UInt8(udpSum & 0xFF)

        return Data(b)
    }

    /// The reply to `request`: addresses and ports mirrored.
    static func buildUDPReply(payload: Data, to request: UDPPacket) -> Data {
        buildUDP(sourceIP: request.destinationIP,
                 destinationIP: request.sourceIP,
                 sourcePort: request.destinationPort,
                 destinationPort: request.sourcePort,
                 payload: payload)
    }

    /// RFC 1071 internet checksum (one's complement of the one's-complement sum).
    static func checksum(_ bytes: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        while i + 1 < bytes.count {
            sum &+= UInt32(bytes[i]) << 8 | UInt32(bytes[i + 1])
            i += 2
        }
        if i < bytes.count { sum &+= UInt32(bytes[i]) << 8 }
        while sum > 0xFFFF { sum = (sum & 0xFFFF) &+ (sum >> 16) }
        return ~UInt16(sum & 0xFFFF)
    }
}
