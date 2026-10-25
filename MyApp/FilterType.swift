import Foundation

public enum MediaCategory: String, CaseIterable, Identifiable {
    case all = "All Photos"
    case screenshots = "Screenshots"
    case videos = "Videos"
    case selfies = "Selfies"
    case recentlyAdded = "Recently Added"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all:
            return "photo.stack"
        case .screenshots:
            return "iphone"
        case .videos:
            return "video.fill"
        case .selfies:
            return "person.crop.square"
        case .recentlyAdded:
            return "clock.arrow.circlepath"
        }
    }
}

public struct MonthYearFilter: Hashable, Identifiable {
    public let month: Int
    public let year: Int

    public var id: String {
        "\(year)-\(month)"
    }

    public var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        if let date = Calendar.current.date(from: comps) {
            return formatter.string(from: date)
        }
        return "\(month)/\(year)"
    }
}
