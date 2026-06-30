import Foundation
import os

/// Downloads the remote domain list, builds a Binary Fuse filter on-device, and
/// writes it into the App Group container for the extension to pick up. The
/// large list is never bundled (it's GPLv3) — the device fetches it from the
/// original source and compiles it locally.
@MainActor
final class BlocklistUpdater: ObservableObject {
    enum Status: Equatable {
        case idle
        case updating
        case updated(Date)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private let log = Logger(subsystem: "com.bykclk.elek", category: "BlocklistUpdater")
    private var defaults: UserDefaults? { UserDefaults(suiteName: AppConstants.appGroupID) }

    var lastUpdated: Date? {
        defaults?.object(forKey: AppConstants.blocklistUpdatedKey) as? Date
    }

    /// Update only if the list is older than `maxAge` (default 24h).
    func updateIfStale(maxAge: TimeInterval = 24 * 3600) {
        if status == .updating { return }
        if let last = lastUpdated, Date().timeIntervalSince(last) < maxAge {
            status = .updated(last)
            return
        }
        Task { await update() }
    }

    func update() async {
        guard status != .updating else { return }
        guard let url = URL(string: AppConstants.remoteListURL),
              let dest = AppGroup.blocklistURL else { return }
        status = .updating
        log.info("downloading list…")
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let text = String(decoding: data, as: UTF8.self)

            // Parse + build off the main actor (CPU work).
            let bin: Data? = await Task.detached(priority: .utility) {
                let domains = DomainListParser.parse(text)
                guard domains.count > 100 else { return nil }   // sanity: not a stub/error page
                return BinaryFuseBuilder.buildBlocklist(domains: domains)
            }.value

            guard let bin else { throw URLError(.cannotParseResponse) }

            // Atomic replace so the extension never mmaps a half-written file.
            try bin.write(to: dest, options: .atomic)

            let now = Date()
            defaults?.set(now, forKey: AppConstants.blocklistUpdatedKey)
            status = .updated(now)
            log.info("blocklist updated: \(bin.count, privacy: .public) bytes")
        } catch {
            status = .failed(error.localizedDescription)
            log.error("update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
