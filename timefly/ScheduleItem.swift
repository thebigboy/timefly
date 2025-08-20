import Foundation
import SwiftData

@Model
final class ScheduleItem: Identifiable {
    @Attribute(.unique) var id: String
    var title: String
    var notes: String?
    var date: Date
    var isCompleted: Bool
    var repeatPattern: RepeatPattern
    var tags: [String]
    var colorHex: String?
    var notificationIds: [String]

    init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        date: Date,
        isCompleted: Bool = false,
        repeatPattern: RepeatPattern = .none,
        tags: [String] = [],
        colorHex: String? = nil,
        notificationIds: [String] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.date = date
        self.isCompleted = isCompleted
        self.repeatPattern = repeatPattern
        self.tags = tags
        self.colorHex = colorHex
        self.notificationIds = notificationIds
    }
}

enum RepeatPattern: Codable, Identifiable, CaseIterable, Equatable {
    case none
    case daily
    case weekly(weekday: Int) // 1..7 (Sunday..Saturday)
    case weekdays              // Mon-Fri
    case everyNDays(n: Int)    // every n days
    case monthlyByDay
    case monthlyNthWeekday(nth: Int, weekday: Int)

    var id: String { title }

    static var allCases: [RepeatPattern] {
        [.none, .daily, .weekly(weekday: 2), .weekdays, .everyNDays(n: 2), .monthlyByDay, .monthlyNthWeekday(nth: 2, weekday: 2)]
    }

    var title: String {
        switch self {
        case .none: return "不重复"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .weekdays: return "工作日"
        case .everyNDays(let n): return "每 \(n) 天"
        case .monthlyByDay: return "每月同一天"
        case .monthlyNthWeekday(let nth, _): return "每月第 \(nth) 个周几"
        }
    }
}
