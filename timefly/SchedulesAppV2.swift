import SwiftUI
import SwiftData
import UserNotifications

@main
struct SchedulesAppV2: App {
    init() {
        // 配置通知类别并设置代理
        NotificationManager.shared.configureCategories()
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }
    
    // 请求通知权限
    private func requestNotificationPermission() {
        Task {
            do {
                try await NotificationManager.shared.requestAuthorization()
                print("通知权限请求成功")
            } catch {
                print("通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup { 
            CalendarView()
                .onAppear {
                    // 应用启动时，请求通知权限并设置每日任务提醒
                    requestNotificationPermission()
                    DailyTaskReminderManager.shared.scheduleDailyReminder()
                }
        }
        .modelContainer(for: [ScheduleItem.self])
        .backgroundTask(.appRefresh("DailyTaskReminderCheck")) { context in
            Task {
                do {
                    // 创建一个临时的ModelContainer用于后台任务
                    let container = try ModelContainer(for: ScheduleItem.self)
                    // 获取ModelContext (异步操作)
                    let modelContext = await container.mainContext
                    // 后台任务中检查明天的待办任务
                    DailyTaskReminderManager.shared.checkTomorrowTasks(modelContext: modelContext)
                } catch {
                    print("后台任务创建ModelContainer失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
