import Foundation

/// "Blocked today" counter shared between the extension (which increments it)
/// and the app (which reads it). Backed by App Group UserDefaults. The count
/// resets automatically when the local calendar day changes.
enum BlockCounter {
    private static let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
    private static let lock = NSLock()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func todayString() -> String {
        dayFormatter.timeZone = TimeZone.current
        return dayFormatter.string(from: Date())
    }

    /// Called by the extension once per blocked query.
    static func increment() {
        guard let d = defaults else { return }
        lock.lock(); defer { lock.unlock() }
        let today = todayString()
        if d.string(forKey: AppConstants.blockedCountDayKey) != today {
            d.set(today, forKey: AppConstants.blockedCountDayKey)
            d.set(0, forKey: AppConstants.blockedCountKey)
        }
        d.set(d.integer(forKey: AppConstants.blockedCountKey) + 1, forKey: AppConstants.blockedCountKey)
    }

    /// Today's count, read by the app. Returns 0 if the stored value is stale
    /// (belongs to a previous day).
    static func today() -> Int {
        guard let d = defaults else { return 0 }
        lock.lock(); defer { lock.unlock() }
        if d.string(forKey: AppConstants.blockedCountDayKey) != todayString() { return 0 }
        return d.integer(forKey: AppConstants.blockedCountKey)
    }
}
