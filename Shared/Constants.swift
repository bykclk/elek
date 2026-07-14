import Foundation

/// App-wide constants for the server-side (encrypted DNS) configuration.
///
/// Elek no longer filters on-device. It configures the system to send all DNS
/// through our DNS-over-HTTPS resolver (a Cloudflare Worker), which blocks ads
/// and trackers and forwards everything else. There is no Network Extension and
/// no App Group — the whole app is a thin `NEDNSSettingsManager` client.
enum AppConstants {
    /// Base address of our resolver.
    private static let resolverHost = "https://elek-dns.omerbuyukcelik.workers.dev"

    /// Our DoH resolver endpoint (RFC 8484). The Worker blocks known ad/tracker
    /// domains (HaGeZi) and forwards the rest. It logs nothing.
    ///
    /// The token (injected from Elek/Secrets.xcconfig, which is never committed)
    /// is a path segment the Worker checks against its AUTH_TOKEN secret. It only
    /// stops someone who reads the public repo from using our resolver — it ships
    /// inside the binary, so it is friction, not security. With no token
    /// configured we fall back to the plain endpoint.
    static var dohURL: String {
        let token = (Bundle.main.object(forInfoDictionaryKey: "ELEKDoHToken") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return token.isEmpty ? "\(resolverHost)/dns-query" : "\(resolverHost)/\(token)/dns-query"
    }

    /// A friendly, human name shown in the system DNS configuration.
    static let configDescription = "Elek"
}
