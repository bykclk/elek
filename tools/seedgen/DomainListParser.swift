import Foundation

/// Parses a downloaded domain list into clean domain strings. Tolerant of the
/// common formats (plain domains, hosts files, adblock syntax) — mirrors the Go
/// `filtergen` parser so on-device builds match build-time ones.
enum DomainListParser {

    static func parse(_ text: String) -> [String] {
        var out: [String] = []
        out.reserveCapacity(100_000)
        text.enumerateLines { line, _ in
            if let d = clean(line) { out.append(d) }
        }
        return out
    }

    static func clean(_ raw: String) -> String? {
        var line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("!") { return nil }

        // Strip inline comments.
        if let hash = line.firstIndex(of: "#") {
            line = String(line[..<hash]).trimmingCharacters(in: .whitespaces)
        }
        // hosts format: "0.0.0.0 ads.example.com" -> last field.
        let fields = line.split(separator: " ", omittingEmptySubsequences: true)
        if fields.count > 1 { line = String(fields[fields.count - 1]) }

        // adblock decorations.
        if line.hasPrefix("||") { line.removeFirst(2) }
        if line.hasSuffix("^") { line.removeLast() }
        if line.hasPrefix("*.") { line.removeFirst(2) }
        if line.hasSuffix(".") { line.removeLast() }

        line = asciiLower(line)
        return isPlausibleDomain(line) ? line : nil
    }

    private static func asciiLower(_ s: String) -> String {
        var bytes = Array(s.utf8)
        for i in bytes.indices where bytes[i] >= 65 && bytes[i] <= 90 { bytes[i] &+= 32 }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func isPlausibleDomain(_ s: String) -> Bool {
        guard s.contains(".") else { return false }
        for b in s.utf8 {
            let ok = (b >= 97 && b <= 122) || (b >= 48 && b <= 57)
                || b == 46 || b == 45 || b == 95  // . - _
            if !ok { return false }
        }
        return true
    }
}
