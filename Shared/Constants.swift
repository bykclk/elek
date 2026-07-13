import Foundation

/// App-wide constants for the server-side (encrypted DNS) configuration.
///
/// Elek no longer filters on-device. It configures the system to send all DNS
/// through our DNS-over-HTTPS resolver (a Cloudflare Worker), which blocks ads
/// and trackers and forwards everything else. There is no Network Extension and
/// no App Group — the whole app is a thin `NEDNSSettingsManager` client.
enum AppConstants {
    /// Our DoH resolver endpoint (RFC 8484). The Worker blocks known ad/tracker
    /// domains (HaGeZi) and forwards the rest. It logs nothing.
    static let dohURL = "https://elek-dns.omerbuyukcelik.workers.dev/dns-query"

    /// A friendly, human name shown in the system DNS configuration.
    static let configDescription = "Elek"
}
