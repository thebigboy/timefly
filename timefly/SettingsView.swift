import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("dailyReminderHour") private var reminderHour: Int = 20
    @AppStorage("dailyReminderMinute") private var reminderMinute: Int = 0
    @State private var showTimePicker = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("每日提醒设置")) {
                    HStack {
                        Text("提醒时间")
                        Spacer()
                        Button(action: {
                            showTimePicker.toggle()
                        }) {
                            Text(String(format: "%02d:%02d", reminderHour, reminderMinute))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if showTimePicker {
                        VStack {
                            HStack {
                                Picker("小时", selection: $reminderHour) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(String(format: "%02d", hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 100)
                                
                                Text(":")
                                    .font(.title)
                                    .padding(.horizontal, 8)
                                
                                Picker("分钟", selection: $reminderMinute) {
                                    ForEach(0..<60, id: \.self) { minute in
                                        Text(String(format: "%02d", minute)).tag(minute)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 100)
                            }
                            .padding(.vertical)
                            
                            Button("保存设置") {
                                // 保存设置并更新定时任务
                                DailyTaskReminderManager.shared.setReminderTime(hour: reminderHour, minute: reminderMinute)
                                showTimePicker = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    Button(action: {
                        // 手动触发检查明天的待办任务
                        // 先请求通知权限，然后在后台线程执行数据查询，UI更新会在主线程进行
                        Task {
                            do {
                                print("开始请求通知权限...")
                                // 先检查当前通知权限状态
                                let center = UNUserNotificationCenter.current()
                                let settings = await center.notificationSettings()
                                print("当前通知权限状态: \(settings.authorizationStatus.rawValue)")
                                
                                // 请求通知权限
                                try await NotificationManager.shared.requestAuthorization()
                                
                                // 再次检查通知权限状态
                                let newSettings = await center.notificationSettings()
                                print("请求后通知权限状态: \(newSettings.authorizationStatus.rawValue)")
                                
                                // 然后检查明天的待办任务
                                print("开始检查明天待办任务...")
                                DailyTaskReminderManager.shared.checkTomorrowTasks(modelContext: modelContext)
                                print("检查明天待办任务完成")
                            } catch {
                                print("通知权限请求失败: \(error.localizedDescription)")
                            }
                        }
                    }) {
                        Text("立即检查明天待办")
                    }
                }
                
                Section(header: Text("关于"), footer: Text("每天将在设定时间检查第二天的待办任务，并发送通知提醒您。")) {
                    Text("每日提醒功能")
                        .font(.headline)
                }
            }
            .navigationTitle("设置")
            .onAppear {
                // 加载当前设置的提醒时间
                let currentTime = DailyTaskReminderManager.shared.getReminderTime()
                if let hour = currentTime.hour {
                    reminderHour = hour
                }
                if let minute = currentTime.minute {
                    reminderMinute = minute
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [ScheduleItem.self])
}