import Foundation

/// Memory-mapped reader for the Binary Fuse (8-bit) blocklist produced by the
/// `filtergen` Go tool. This is a pure-Swift reimplementation of
/// xorfilter.BinaryFuse[uint8].Contains (github.com/FastFilter/xorfilter
/// v0.2.1) plus the FNV-1a 64-bit domain hashing — kept byte-for-byte
/// compatible with the writer.
final class Blocklist {

    private let data: Data        // mmapped file; retained to keep the mapping alive
    private let fpBase: Int       // index of fingerprints[0] within `data`

    private let seed: UInt64
    private let segmentLength: UInt32
    private let segmentLengthMask: UInt32
    private let segmentCountLength: UInt32
    private let fingerprintCount: UInt32

    /// Header layout (little-endian), total 32 bytes before fingerprints:
    /// magic(4) version(1) hashType(1) reserved(2) seed(8)
    /// segmentLength(4) segmentLengthMask(4) segmentCountLength(4) fingerprintCount(4)
    private static let headerSize = 32

    init?(url: URL) {
        guard let d = try? Data(contentsOf: url, options: .mappedIfSafe),
              d.count >= Self.headerSize else { return nil }

        let base = d.startIndex
        // magic "BFF8"
        guard d[base] == 0x42, d[base + 1] == 0x46, d[base + 2] == 0x46, d[base + 3] == 0x38,
              d[base + 4] == 1,            // version
              d[base + 5] == 1 else {      // hashType = fnv1a64
            return nil
        }

        self.seed = Self.readLE(d, 8, UInt64.self)
        self.segmentLength = Self.readLE(d, 16, UInt32.self)
        self.segmentLengthMask = Self.readLE(d, 20, UInt32.self)
        self.segmentCountLength = Self.readLE(d, 24, UInt32.self)
        self.fingerprintCount = Self.readLE(d, 28, UInt32.self)

        guard d.count >= Self.headerSize + Int(fingerprintCount) else { return nil }
        self.data = d
        self.fpBase = base + Self.headerSize
    }

    // MARK: Public membership

    /// True if `qname` or any of its parent suffixes is in the blocklist
    /// (ads.x.com -> x.com -> com).
    func blocks(_ qname: String) -> Bool {
        var sub = Substring(qname)
        while !sub.isEmpty {
            if contains(key: Self.fnv1a64(sub)) { return true }
            guard let dot = sub.firstIndex(of: ".") else { break }
            sub = sub[sub.index(after: dot)...]
        }
        return false
    }

    // MARK: Binary Fuse lookup (port of BinaryFuse[uint8].Contains)

    func contains(key: UInt64) -> Bool {
        let hash = Self.mixsplit(key, seed)
        var f = UInt8(truncatingIfNeeded: Self.fingerprint(hash))
        let (h0, h1, h2) = getHashFromHash(hash)
        f ^= fingerprint(at: h0) ^ fingerprint(at: h1) ^ fingerprint(at: h2)
        return f == 0
    }

    private func getHashFromHash(_ hash: UInt64) -> (UInt32, UInt32, UInt32) {
        let hi = hash.multipliedFullWidth(by: UInt64(segmentCountLength)).high
        let h0 = UInt32(truncatingIfNeeded: hi)
        var h1 = h0 &+ segmentLength
        var h2 = h1 &+ segmentLength
        h1 ^= UInt32(truncatingIfNeeded: hash >> 18) & segmentLengthMask
        h2 ^= UInt32(truncatingIfNeeded: hash) & segmentLengthMask
        return (h0, h1, h2)
    }

    @inline(__always)
    private func fingerprint(at index: UInt32) -> UInt8 {
        data[fpBase + Int(index)]
    }

    // MARK: Hash primitives (must match xorfilter / filtergen exactly)

    @inline(__always)
    private static func murmur64(_ h0: UInt64) -> UInt64 {
        var h = h0
        h ^= h >> 33
        h = h &* 0xff51afd7ed558ccd
        h ^= h >> 33
        h = h &* 0xc4ceb9fe1a85ec53
        h ^= h >> 33
        return h
    }

    @inline(__always)
    private static func mixsplit(_ key: UInt64, _ seed: UInt64) -> UInt64 {
        murmur64(key &+ seed)
    }

    @inline(__always)
    private static func fingerprint(_ hash: UInt64) -> UInt64 {
        hash ^ (hash >> 32)
    }

    /// FNV-1a 64-bit over ASCII-lowercased UTF-8 bytes, no trailing dot.
    @inline(__always)
    static func fnv1a64(_ s: Substring) -> UInt64 {
        var h: UInt64 = 14695981039346656037
        for var b in s.utf8 {
            if b >= 65 && b <= 90 { b &+= 32 } // ASCII A-Z -> a-z
            h ^= UInt64(b)
            h = h &* 1099511628211
        }
        return h
    }

    // MARK: Little-endian header readers

    private static func readLE<T: FixedWidthInteger>(_ d: Data, _ offset: Int, _ type: T.Type) -> T {
        var v: T = 0
        let start = d.startIndex + offset
        withUnsafeMutableBytes(of: &v) { dst in
            _ = d.copyBytes(to: dst, from: start ..< start + MemoryLayout<T>.size)
        }
        return T(littleEndian: v)
    }
}
