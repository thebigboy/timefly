import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() { super.init() }

    func configureCategories() {
        let snooze5 = UNNotificationAction(identifier: "SNOOZE_5", title: "稍后 5 分钟")
        let snooze10 = UNNotificationAction(identifier: "SNOOZE_10", title: "稍后 10 分钟")
        let snooze30 = UNNotificationAction(identifier: "SNOOZE_30", title: "稍后 30 分钟")
        let category = UNNotificationCategory(identifier: "REMINDER_CATEGORY", actions: [snooze5, snooze10, snooze30], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        if !granted { print("[Notif] 用户未授权") }
        configureCategories()
    }

    func cancelNotifications(ids: [String]) {
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func scheduleNotifications(for item: ScheduleItem) async throws -> [String] {
        let content = UNMutableNotificationContent()
        content.title = item.title
        if let notes = item.notes, !notes.isEmpty { content.body = notes }
        content.sound = .default
        content.categoryIdentifier = "REMINDER_CATEGORY"

        let baseDate = item.date
        var ids: [String] = []

        func add(_ trigger: UNNotificationTrigger) async throws {
            let id = UUID().uuidString
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try await UNUserNotificationCenter.current().add(request)
            ids.append(id)
        }

        let cal = Calendar.current
        switch item.repeatPattern {
        case .none:
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: baseDate)
            try await add(UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        case .daily:
            let comps = cal.dateComponents([.hour, .minute], from: baseDate)
            try await add(UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        case .weekly(let weekday):
            var comps = cal.dateComponents([.weekday, .hour, .minute], from: baseDate)
            comps.weekday = weekday
            try await add(UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        case .weekdays:
            for wd in 2...6 {
                var comps = cal.dateComponents([.weekday, .hour, .minute], from: baseDate)
                comps.weekday = wd
                try await add(UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
            }
        case .everyNDays(let n):
            let sec = max(60, n * 24 * 60 * 60)
            try await add(UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(sec), repeats: true))
        case .monthlyByDay:
            let comps = cal.dateComponents([.day, .hour, .minute], from: baseDate)
            try await add(UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        case .monthlyNthWeekday(let nth, let weekday):
            var comps = DateComponents()
            comps.weekOfMonth = nth
            comps.weekday = weekday
            comps.hour = cal.component(.hour, from: baseDate)
            comps.minute = cal.component(.minute, from: baseDate)
            try await add(UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        case .yearly:
            let month = cal.component(.month, from: baseDate)
            let day = cal.component(.day, from: baseDate)
            let hour = cal.component(.hour, from: baseDate)
            let minute = cal.component(.minute, from: baseDate)
            
            // 获取当前年份
            let currentYear = cal.component(.year, from: Date())
            
            // 为当前年份和未来两年创建通知（共3年）
            for yearOffset in 0..<3 {
                var comps = DateComponents()
                comps.year = currentYear + yearOffset
                comps.month = month
                comps.day = day
                comps.hour = hour
                comps.minute = minute
                
                // 创建日期以检查是否已过期
                if let futureDate = cal.date(from: comps), futureDate > Date() {
                    try await add(UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                }
            }
            
        }
        return ids
    }

    // 处理通知响应（用户点击通知）
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        switch response.actionIdentifier {
        case "SNOOZE_5": await rescheduleSnooze(content: content, minutes: 5)
        case "SNOOZE_10": await rescheduleSnooze(content: content, minutes: 10)
        case "SNOOZE_30": await rescheduleSnooze(content: content, minutes: 30)
        default: break
        }
    }
    
    // 处理前台通知显示
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // 允许在前台显示通知，包括横幅、声音和角标
        print("前台通知将被显示: \(notification.request.identifier)")
        return [.banner, .sound, .badge, .list]
    }

    private func rescheduleSnooze(content: UNNotificationContent, minutes: Int) async {
        let mutable = UNMutableNotificationContent()
        mutable.title = content.title
        mutable.subtitle = content.subtitle
        mutable.body = content.body
        mutable.userInfo = content.userInfo
        mutable.badge = content.badge
        mutable.sound = .default
        mutable.categoryIdentifier = "REMINDER_CATEGORY"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: mutable, trigger: trigger)
        do { try await UNUserNotificationCenter.current().add(request) } catch { print("Snooze 失败: \(error)") }
    }
}
