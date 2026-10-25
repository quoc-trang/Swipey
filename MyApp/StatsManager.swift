import Foundation

@Observable
public final class StatsManager {
    public static let shared = StatsManager()

    private let totalDeletedKey = "swipeclean_total_deleted_count"
    private let totalBytesFreedKey = "swipeclean_total_bytes_freed"
    private let lastCleanDateKey = "swipeclean_last_clean_date"
    private let streakCountKey = "swipeclean_streak_count"

    public var totalDeletedCount: Int {
        get { UserDefaults.standard.integer(forKey: totalDeletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: totalDeletedKey) }
    }

    public var totalBytesFreed: Int64 {
        get {
            let val = UserDefaults.standard.object(forKey: totalBytesFreedKey) as? Int64
            return val ?? 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: totalBytesFreedKey)
        }
    }

    public var streakDays: Int {
        get { UserDefaults.standard.integer(forKey: streakCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: streakCountKey) }
    }

    public func recordDeletion(count: Int, bytesFreed: Int64) {
        totalDeletedCount += count
        totalBytesFreed += bytesFreed

        // Update streak
        let now = Date()
        let calendar = Calendar.current
        if let lastDate = UserDefaults.standard.object(forKey: lastCleanDateKey) as? Date {
            if calendar.isDateInYesterday(lastDate) {
                streakDays += 1
            } else if !calendar.isDateInToday(lastDate) {
                streakDays = 1
            }
        } else {
            streakDays = 1
        }
        UserDefaults.standard.set(now, forKey: lastCleanDateKey)
    }

    public var formattedStorageSaved: String {
        ByteCountFormatter.string(fromByteCount: totalBytesFreed, countStyle: .file)
    }
}
