import Foundation
import os

/// Copies the blocklist.bin shipped in the app bundle into the shared App Group
/// container so the DNS proxy extension can memory-map it. Runs on every app
/// launch but only copies when the bundled file is new or changed (compared by
/// size), so updating the app updates the on-device blocklist.
enum BlocklistInstaller {
    private static let log = Logger(subsystem: "com.elek.app", category: "BlocklistInstaller")

    static func installIfNeeded() {
        guard let bundled = Bundle.main.url(forResource: "blocklist", withExtension: "bin") else {
            log.error("blocklist.bin missing from app bundle")
            return
        }
        guard let dest = AppGroup.blocklistURL else {
            log.error("App Group container unavailable")
            return
        }

        let fm = FileManager.default
        if let bundledSize = fileSize(bundled), let destSize = fileSize(dest),
           bundledSize == destSize {
            log.info("blocklist up to date (\(destSize, privacy: .public) bytes)")
            return
        }

        do {
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: bundled, to: dest)
            log.info("installed blocklist (\(fileSize(dest) ?? 0, privacy: .public) bytes)")
        } catch {
            log.error("install failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func fileSize(_ url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
    }
}
