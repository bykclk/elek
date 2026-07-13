import Foundation

/// On-device builder for the Binary Fuse (8-bit) blocklist. Pure-Swift port of
/// `xorfilter.NewBinaryFuse[uint8]` construction (github.com/FastFilter/xorfilter
/// v0.2.1). Produces a blocklist.bin in the same little-endian format as the Go
/// `filtergen` tool, readable by `Blocklist.swift`.
///
/// This lets the app rebuild the filter on-device from a freshly downloaded
/// domain list, without shipping the GPL-licensed source list or running Go.
enum BinaryFuseBuilder {

    struct Filter {
        var seed: UInt64
        var segmentLength: UInt32
        var segmentLengthMask: UInt32
        var segmentCountLength: UInt32
        var fingerprints: [UInt8]
    }

    static let maxIterations = 1024

    // MARK: - Hash primitives (must match the reader / xorfilter exactly)

    @inline(__always) static func murmur64(_ h0: UInt64) -> UInt64 {
        var h = h0
        h ^= h >> 33; h = h &* 0xff51afd7ed558ccd
        h ^= h >> 33; h = h &* 0xc4ceb9fe1a85ec53
        h ^= h >> 33
        return h
    }
    @inline(__always) static func mixsplit(_ key: UInt64, _ seed: UInt64) -> UInt64 {
        murmur64(key &+ seed)
    }
    @inline(__always) static func fingerprint(_ hash: UInt64) -> UInt64 {
        hash ^ (hash >> 32)
    }
    @inline(__always) static func splitmix64(_ seed: inout UInt64) -> UInt64 {
        seed = seed &+ 0x9E3779B97F4A7C15
        var z = seed
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    static func calculateSegmentLength(_ size: UInt32) -> UInt32 {
        if size == 0 { return 4 }
        return UInt32(1) << Int(floor(log(Double(size)) / log(3.33) + 2.25))
    }
    static func calculateSizeFactor(_ size: UInt32) -> Double {
        max(1.125, 0.875 + 0.25 * log(1_000_000) / log(Double(size)))
    }

    @inline(__always)
    static func getHash(_ hash: UInt64, _ segLen: UInt32, _ segMask: UInt32,
                        _ segCountLen: UInt32) -> (UInt32, UInt32, UInt32) {
        let hi = hash.multipliedFullWidth(by: UInt64(segCountLen)).high
        let h0 = UInt32(truncatingIfNeeded: hi)
        var h1 = h0 &+ segLen
        var h2 = h1 &+ segLen
        h1 ^= UInt32(truncatingIfNeeded: hash >> 18) & segMask
        h2 ^= UInt32(truncatingIfNeeded: hash) & segMask
        return (h0, h1, h2)
    }
    @inline(__always) static func mod3(_ x: UInt8) -> UInt8 { x > 2 ? x &- 3 : x }

    // MARK: - FNV-1a 64-bit (ASCII-lowercased), matches filtergen & reader

    static func fnv1a64(_ s: String) -> UInt64 {
        var h: UInt64 = 14695981039346656037
        for var b in s.utf8 {
            if b >= 65 && b <= 90 { b &+= 32 }
            h ^= UInt64(b)
            h = h &* 1099511628211
        }
        return h
    }

    // MARK: - Construction

    /// Build a filter from domain strings. Returns serialized blocklist.bin data,
    /// or nil if the set is empty or construction fails.
    static func buildBlocklist(domains: [String]) -> Data? {
        var seen = Set<UInt64>()
        var keys: [UInt64] = []
        keys.reserveCapacity(domains.count)
        for d in domains {
            let k = fnv1a64(d)
            if seen.insert(k).inserted { keys.append(k) }
        }
        guard let filter = build(keys: keys) else { return nil }
        return serialize(filter)
    }

    /// Port of NewBinaryFuse[uint8]. `keys` must be distinct.
    static func build(keys: [UInt64]) -> Filter? {
        let size0 = UInt32(keys.count)
        guard size0 > 0 else { return nil }

        // initializeParameters
        let arity: UInt32 = 3
        var segmentLength = calculateSegmentLength(size0)
        if segmentLength > 262144 { segmentLength = 262144 }
        let segmentLengthMask = segmentLength &- 1
        let sizeFactor = calculateSizeFactor(size0)
        let capacity: UInt32 = size0 > 1 ? UInt32((Double(size0) * sizeFactor).rounded()) : 0
        let initSegmentCount = (capacity &+ segmentLength &- 1) / segmentLength &- (arity - 1)
        var arrayLength = (initSegmentCount &+ arity - 1) &* segmentLength
        var segmentCount = (arrayLength &+ segmentLength &- 1) / segmentLength
        if segmentCount <= arity - 1 { segmentCount = 1 } else { segmentCount = segmentCount &- (arity - 1) }
        arrayLength = (segmentCount &+ arity - 1) &* segmentLength
        let segmentCountLength = segmentCount &* segmentLength

        let fpLen = Int(arrayLength)
        var fingerprints = [UInt8](repeating: 0, count: fpLen)

        // Working arrays.
        var alone = [UInt32](repeating: 0, count: fpLen)
        var t2count = [UInt8](repeating: 0, count: fpLen)
        var reverseH = [UInt8](repeating: 0, count: Int(size0))
        var t2hash = [UInt64](repeating: 0, count: fpLen)
        var reverseOrder = [UInt64](repeating: 0, count: Int(size0) + 1)
        reverseOrder[Int(size0)] = 1
        var h012 = [UInt32](repeating: 0, count: 6)

        var rngcounter: UInt64 = 1
        var seed = splitmix64(&rngcounter)
        var size = size0

        var iterations = 0
        while true {
            iterations += 1
            if iterations > maxIterations { return nil }

            var blockBits = 1
            while (1 << blockBits) < segmentCount { blockBits += 1 }
            let blockRange = 1 << blockBits
            var startPos = [Int](repeating: 0, count: blockRange)
            for i in 0..<blockRange {
                startPos[i] = Int((UInt64(i) &* UInt64(size)) >> blockBits)
            }
            for key in keys {
                let hash = mixsplit(key, seed)
                var segmentIndex = Int(hash >> (64 - blockBits))
                while reverseOrder[startPos[segmentIndex]] != 0 {
                    segmentIndex += 1
                    segmentIndex &= (blockRange - 1)
                }
                reverseOrder[startPos[segmentIndex]] = hash
                startPos[segmentIndex] += 1
            }

            var error = 0
            var duplicates: UInt32 = 0
            for i in 0..<Int(size) {
                let hash = reverseOrder[i]
                let (i1, i2, i3) = getHash(hash, segmentLength, segmentLengthMask, segmentCountLength)
                let a = Int(i1), b = Int(i2), c = Int(i3)
                t2count[a] = t2count[a] &+ 4
                t2hash[a] ^= hash
                t2count[b] = (t2count[b] &+ 4) ^ 1
                t2hash[b] ^= hash
                t2count[c] = (t2count[c] &+ 4) ^ 2
                t2hash[c] ^= hash
                if (t2hash[a] & t2hash[b] & t2hash[c]) == 0 {
                    if (t2hash[a] == 0 && t2count[a] == 8)
                        || (t2hash[b] == 0 && t2count[b] == 8)
                        || (t2hash[c] == 0 && t2count[c] == 8) {
                        duplicates += 1
                        t2count[a] = t2count[a] &- 4
                        t2hash[a] ^= hash
                        t2count[b] = (t2count[b] &- 4) ^ 1
                        t2hash[b] ^= hash
                        t2count[c] = (t2count[c] &- 4) ^ 2
                        t2hash[c] ^= hash
                    }
                }
                if t2count[a] < 4 || t2count[b] < 4 || t2count[c] < 4 { error = 1 }
            }
            if error == 1 {
                for i in 0..<Int(size) { reverseOrder[i] = 0 }
                for i in 0..<fpLen { t2count[i] = 0; t2hash[i] = 0 }
                seed = splitmix64(&rngcounter)
                continue
            }

            // Peel.
            var qsize = 0
            for i in 0..<fpLen {
                alone[qsize] = UInt32(i)
                if (t2count[i] >> 2) == 1 { qsize += 1 }
            }
            var stacksize: UInt32 = 0
            while qsize > 0 {
                qsize -= 1
                let index = Int(alone[qsize])
                if (t2count[index] >> 2) == 1 {
                    let hash = t2hash[index]
                    let found = t2count[index] & 3
                    reverseH[Int(stacksize)] = found
                    reverseOrder[Int(stacksize)] = hash
                    stacksize += 1

                    let (i1, i2, i3) = getHash(hash, segmentLength, segmentLengthMask, segmentCountLength)
                    h012[1] = i2
                    h012[2] = i3
                    h012[3] = i1
                    h012[4] = h012[1]

                    let o1 = Int(h012[Int(found) + 1])
                    alone[qsize] = UInt32(o1)
                    if (t2count[o1] >> 2) == 2 { qsize += 1 }
                    t2count[o1] = (t2count[o1] &- 4) ^ mod3(found &+ 1)
                    t2hash[o1] ^= hash

                    let o2 = Int(h012[Int(found) + 2])
                    alone[qsize] = UInt32(o2)
                    if (t2count[o2] >> 2) == 2 { qsize += 1 }
                    t2count[o2] = (t2count[o2] &- 4) ^ mod3(found &+ 2)
                    t2hash[o2] ^= hash
                }
            }

            if stacksize + duplicates == size {
                size = stacksize
                break
            }
            // (We pre-dedupe keys, so the duplicate-pruning branch never runs.)
            for i in 0..<Int(size) { reverseOrder[i] = 0 }
            for i in 0..<fpLen { t2count[i] = 0; t2hash[i] = 0 }
            seed = splitmix64(&rngcounter)
        }

        if size > 0 {
            var i = Int(size) - 1
            while i >= 0 {
                let hash = reverseOrder[i]
                let xor2 = UInt8(truncatingIfNeeded: fingerprint(hash))
                let (i1, i2, i3) = getHash(hash, segmentLength, segmentLengthMask, segmentCountLength)
                let found = reverseH[i]
                h012[0] = i1
                h012[1] = i2
                h012[2] = i3
                h012[3] = h012[0]
                h012[4] = h012[1]
                fingerprints[Int(h012[Int(found)])] =
                    xor2 ^ fingerprints[Int(h012[Int(found) + 1])] ^ fingerprints[Int(h012[Int(found) + 2])]
                i -= 1
            }
        }

        return Filter(seed: seed,
                      segmentLength: segmentLength,
                      segmentLengthMask: segmentLengthMask,
                      segmentCountLength: segmentCountLength,
                      fingerprints: fingerprints)
    }

    // MARK: - Serialization (matches filtergen / Blocklist.swift format)

    static func serialize(_ f: Filter) -> Data {
        var d = Data()
        d.append(contentsOf: [0x42, 0x46, 0x46, 0x38]) // "BFF8"
        d.append(1) // version
        d.append(1) // hashType = fnv1a64
        appendLE(&d, UInt16(0)) // reserved
        appendLE(&d, f.seed)
        appendLE(&d, f.segmentLength)
        appendLE(&d, f.segmentLengthMask)
        appendLE(&d, f.segmentCountLength)
        appendLE(&d, UInt32(f.fingerprints.count))
        d.append(contentsOf: f.fingerprints)
        return d
    }

    private static func appendLE<T: FixedWidthInteger>(_ d: inout Data, _ value: T) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
    }
}
