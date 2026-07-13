// Pure-TypeScript port of xorfilter.BinaryFuse[uint8].Contains + FNV-1a 64-bit
// domain hashing. Byte-for-byte compatible with the Swift reader/writer
// (ElekProxy/Blocklist.swift, Elek/BinaryFuseBuilder.swift) and the same
// blocklist.bin format. Verified against the committed seed list in test/verify.ts.
//
// All 64-bit arithmetic uses BigInt — JS numbers and bitwise operators are only
// safe to 32 bits, and this filter's hashing is defined over uint64.

const MASK64 = (1n << 64n) - 1n;

function murmur64(h0: bigint): bigint {
  let h = h0 & MASK64;
  h ^= h >> 33n;
  h = (h * 0xff51afd7ed558ccdn) & MASK64;
  h ^= h >> 33n;
  h = (h * 0xc4ceb9fe1a85ec53n) & MASK64;
  h ^= h >> 33n;
  return h & MASK64;
}

function mixsplit(key: bigint, seed: bigint): bigint {
  return murmur64((key + seed) & MASK64);
}

function fingerprint64(hash: bigint): bigint {
  return (hash ^ (hash >> 32n)) & MASK64;
}

/// FNV-1a 64-bit over ASCII-lowercased bytes. DNS wire names are always ASCII
/// (IDNs are punycode `xn--`), so iterating UTF-16 code units matches the
/// Swift reader's byte iteration exactly.
export function fnv1a64(s: string): bigint {
  let h = 14695981039346656037n;
  for (let i = 0; i < s.length; i++) {
    let b = s.charCodeAt(i);
    if (b >= 65 && b <= 90) b += 32; // ASCII A-Z -> a-z
    h ^= BigInt(b & 0xff);
    h = (h * 1099511628211n) & MASK64;
  }
  return h;
}

/// Memory-light reader for the Binary Fuse (8-bit) blocklist.
export class BinaryFuse {
  private readonly fp: Uint8Array; // fingerprints[]
  private readonly seed: bigint;
  private readonly segmentLength: number;
  private readonly segmentLengthMask: number;
  private readonly segmentCountLength: bigint;

  /// Header layout (little-endian, 32 bytes before fingerprints):
  /// magic(4) version(1) hashType(1) reserved(2) seed(8)
  /// segmentLength(4) segmentLengthMask(4) segmentCountLength(4) fingerprintCount(4)
  constructor(data: Uint8Array) {
    if (data.length < 32) throw new Error("blocklist: too small");
    if (data[0] !== 0x42 || data[1] !== 0x46 || data[2] !== 0x46 || data[3] !== 0x38) {
      throw new Error("blocklist: bad magic (expected BFF8)");
    }
    if (data[4] !== 1 || data[5] !== 1) throw new Error("blocklist: bad version/hashType");

    const dv = new DataView(data.buffer, data.byteOffset, data.byteLength);
    this.seed = dv.getBigUint64(8, true);
    this.segmentLength = dv.getUint32(16, true);
    this.segmentLengthMask = dv.getUint32(20, true);
    this.segmentCountLength = BigInt(dv.getUint32(24, true));
    const fingerprintCount = dv.getUint32(28, true);
    if (data.length < 32 + fingerprintCount) throw new Error("blocklist: truncated fingerprints");
    this.fp = data.subarray(32, 32 + fingerprintCount);
  }

  /// True if `qname` or any of its parent suffixes is blocked
  /// (ads.x.com -> x.com -> com).
  blocks(qname: string): boolean {
    let sub = qname;
    while (sub.length > 0) {
      if (this.contains(fnv1a64(sub))) return true;
      const dot = sub.indexOf(".");
      if (dot < 0) break;
      sub = sub.slice(dot + 1);
    }
    return false;
  }

  /// Port of BinaryFuse[uint8].Contains.
  contains(key: bigint): boolean {
    const hash = mixsplit(key, this.seed);
    let f = Number(fingerprint64(hash) & 0xffn);
    const [h0, h1, h2] = this.getHash(hash);
    f ^= this.fp[h0] ^ this.fp[h1] ^ this.fp[h2];
    return (f & 0xff) === 0;
  }

  private getHash(hash: bigint): [number, number, number] {
    // high 64 bits of the 128-bit product (Swift multipliedFullWidth().high)
    const hi = (hash * this.segmentCountLength) >> 64n;
    const h0 = Number(hi & 0xffffffffn);
    let h1 = (h0 + this.segmentLength) >>> 0;
    let h2 = (h1 + this.segmentLength) >>> 0;
    h1 = (h1 ^ (Number((hash >> 18n) & 0xffffffffn) & this.segmentLengthMask)) >>> 0;
    h2 = (h2 ^ (Number(hash & 0xffffffffn) & this.segmentLengthMask)) >>> 0;
    return [h0, h1, h2];
  }
}
