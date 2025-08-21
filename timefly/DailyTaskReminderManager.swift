import Foundation
import SwiftData
import UserNotifications
import SwiftUI

final class DailyTaskReminderManager {
    static let shared = DailyTaskReminderManager()
    
    // 默认提醒时间：20:00
    private var reminderTime: DateComponents {
        get {
            let defaults = UserDefaults.standard
            let hour = defaults.integer(forKey: "dailyReminderHour")
            let minute = defaults.integer(forKey: "dailyReminderMinute")
            
            var components = DateComponents()
            components.hour = hour > 0 ? hour : 20 // 默认20:00
            components.minute = minute >= 0 ? minute : 0
            return components
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.hour ?? 20, forKey: "dailyReminderHour")
            defaults.set(newValue.minute ?? 0, forKey: "dailyReminderMinute")
        }
    }
    
    // 通知标识符
    private let dailyReminderNotificationId = "com.timefly.dailyTaskReminder"
    
    private init() {}
    
    // 设置每日提醒时间
    func setReminderTime(hour: Int, minute: Int) {
        reminderTime.hour = hour
        reminderTime.minute = minute
        
        // 更新定时任务
        scheduleDailyReminder()
    }
    
    // 获取当前设置的提醒时间
    func getReminderTime() -> DateComponents {
        return reminderTime
    }
    
    // 启动定时任务
    func scheduleDailyReminder() {
        // 取消之前的通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderNotificationId])
        
        // 创建触发器，每天在设定时间触发
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderTime, repeats: true)
        
        // 创建通知内容（临时内容，实际内容将在触发时动态生成）
        let content = UNMutableNotificationContent()
        content.title = "每日待办提醒"
        content.body = "正在检查明天的待办任务..."
        content.sound = .default
        
        // 创建通知请求
        let request = UNNotificationRequest(
            identifier: dailyReminderNotificationId,
            content: content,
            trigger: trigger
        )
        
        // 添加通知请求
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("设置每日任务提醒失败: \(error.localizedDescription)")
            } else {
                print("每日任务提醒已设置，将在每天 \(self.reminderTime.hour ?? 20):\(self.reminderTime.minute ?? 0) 触发")
            }
        }
    }
    
    // 检查明天的待办任务并发送通知
    func checkTomorrowTasks(modelContext: ModelContext) {
        // 获取明天的日期范围
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(24 * 60 * 60))
        let tomorrowEnd = Calendar.current.date(byAdding: .day, value: 1, to: tomorrow)!
        
        // 查询明天的待办任务
        let predicate = #Predicate<ScheduleItem> { item in
            !item.isCompleted && 
            item.date >= tomorrow && 
            item.date < tomorrowEnd
        }
        
        do {
            let descriptor = FetchDescriptor<ScheduleItem>(predicate: predicate)
            let tomorrowTasks = try modelContext.fetch(descriptor)
            
            // 确保在主线程发送通知
            DispatchQueue.main.async {
                // 发送通知
                self.sendTaskNotification(tasks: tomorrowTasks)
            }
        } catch {
            print("查询明天待办任务失败: \(error.localizedDescription)")
        }
    }
    
    // 发送任务通知
    private func sendTaskNotification(tasks: [ScheduleItem]) {
        // 此方法已在主线程中调用
        let content = UNMutableNotificationContent()
        
        if tasks.isEmpty {
            // 没有待办任务
            content.title = "明天的安排"
            content.body = "明天您还没有待办哦😊"
        } else {
            // 有待办任务
            let count = tasks.count
            let taskTitles = tasks.map { $0.title }
            let taskList = taskTitles.joined(separator: "、")
            
            content.title = "明天的安排"
            content.body = "您明天共有\(count)项待办，分别是\(taskList)，请记得处理哦，到点我会提醒您。"
        }
        
        content.sound = .default
        
        // 立即发送通知
        let request = UNNotificationRequest(
            identifier: "\(dailyReminderNotificationId)_result",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送任务通知失败: \(error.localizedDescription)")
            } else {
                print("通知发送成功，标识符: \(request.identifier)")
                print("通知内容: \(content.title) - \(content.body)")
                
                // 检查当前通知权限状态
                Task {
                    let center = UNUserNotificationCenter.current()
                    let settings = await center.notificationSettings()
                    print("发送通知时的权限状态: \(settings.authorizationStatus.rawValue)")
                    print("通知提醒设置: \(settings.alertSetting.rawValue)")
                    print("通知声音设置: \(settings.soundSetting.rawValue)")
                    print("通知角标设置: \(settings.badgeSetting.rawValue)")
                }
            }
        }
    }
}