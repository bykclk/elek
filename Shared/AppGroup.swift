import Foundation

/// File locations inside the shared App Group container, used by both the app
/// (which installs the blocklist) and the extension (which reads it).
enum AppGroup {
    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)
    }

    /// Path to the memory-mapped Binary Fuse blocklist in the shared container.
    static var blocklistURL: URL? {
        containerURL?.appendingPathComponent(AppConstants.blocklistFilename)
    }
}
