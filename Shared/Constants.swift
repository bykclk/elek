import Foundation

/// Identifiers shared between the app and the DNS proxy extension.
///
/// If you change these, also update:
///   - the App Group strings in Elek/Elek.entitlements and
///     ElekProxy/ElekProxy.entitlements
///   - the bundle identifiers in project.yml
enum AppConstants {
    /// App Group container shared by the app and the extension.
    /// Must match `com.apple.security.application-groups` in both entitlements.
    static let appGroupID = "group.com.bykclk.elek"

    /// Bundle identifier of the filtering extension. Must equal the extension
    /// target's PRODUCT_BUNDLE_IDENTIFIER in project.yml.
    static let proxyBundleID = "com.bykclk.elek.dnsproxy"

    /// Virtual resolver the tunnel advertises to the system. Only this /32 is
    /// routed into the tunnel, so ONLY DNS enters it — all other traffic flows
    /// over the normal interfaces untouched.
    static let dnsServerIP = "10.7.0.1"
    /// The tunnel's own virtual interface address.
    static let tunnelClientIP = "10.7.0.2"

    /// Filename of the memory-mapped Binary Fuse blocklist inside the App Group
    /// container (written in step 3).
    static let blocklistFilename = "blocklist.bin"

    /// Shared UserDefaults key for the "blocked today" counter (step 4).
    static let blockedCountKey = "blockedToday.count"
    /// Shared UserDefaults key for the day (yyyy-MM-dd) the counter belongs to.
    static let blockedCountDayKey = "blockedToday.day"

    /// Shared UserDefaults key for when the on-device blocklist was last updated.
    static let blocklistUpdatedKey = "blocklist.lastUpdated"

    /// Remote domain list fetched on-device to rebuild the blocklist. HaGeZi is
    /// GPLv3, so we never bundle/redistribute it — the user's device fetches it
    /// from the original source and builds the filter locally.
    static let remoteListURL = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/light.txt"
}
