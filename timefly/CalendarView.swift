import SwiftUI
import SwiftData

// MARK: - 中文日期格式化工具函数

private func formatChineseMonth(_ date: Date) -> String {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: date)
    let year = calendar.component(.year, from: date)
    
    let monthNames = [
        1: "一月", 2: "二月", 3: "三月", 4: "四月", 5: "五月", 6: "六月",
        7: "七月", 8: "八月", 9: "九月", 10: "十月", 11: "十一月", 12: "十二月"
    ]
    
    return "\(monthNames[month] ?? "\(month)月") \(year)年"
}

private func formatChineseDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    let weekday = calendar.component(.weekday, from: date)
    
    let monthNames = [
        1: "一月", 2: "二月", 3: "三月", 4: "四月", 5: "五月", 6: "六月",
        7: "七月", 8: "八月", 9: "九月", 10: "十月", 11: "十一月", 12: "十二月"
    ]
    
    let weekdayNames = [
        1: "星期日", 2: "星期一", 3: "星期二", 4: "星期三", 
        5: "星期四", 6: "星期五", 7: "星期六"
    ]
    
    return "\(year)年\(monthNames[month] ?? "\(month)月")\(day)日 \(weekdayNames[weekday] ?? "")"
}

private func formatChineseTime(_ date: Date) -> String {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    
    let hourStr = hour < 10 ? "0\(hour)" : "\(hour)"
    let minuteStr = minute < 10 ? "0\(minute)" : "\(minute)"
    
    return "\(hourStr):\(minuteStr)"
}

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query private var items: [ScheduleItem]
    @State private var showAdd = false
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var searchText = ""
    @State private var selectedTag: String? = nil
    
    init() {
        _items = Query(sort: [SortDescriptor(\ScheduleItem.date, order: .forward)])
    }
    
    var filtered: [ScheduleItem] {
        items.filter { item in
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let hit = q.isEmpty || item.title.localizedCaseInsensitiveContains(q) || (item.notes ?? "").localizedCaseInsensitiveContains(q) || item.tags.contains { $0.localizedCaseInsensitiveContains(q) }
            let tagHit = selectedTag == nil || item.tags.contains(selectedTag!)
            return hit && tagHit
        }
    }
    
    var allTags: [String] { Array(Set(items.flatMap { $0.tags })).sorted() }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 标签过滤器
                if !allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TagChip(text: "全部", isSelected: selectedTag == nil) { selectedTag = nil }
                            ForEach(allTags, id: \.self) { t in
                                TagChip(text: t, isSelected: selectedTag == t) { selectedTag = (selectedTag == t ? nil : t) }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemBackground))
                }
                
                // 日历视图
                CalendarGridView(
                    currentMonth: $currentMonth,
                    selectedDate: $selectedDate,
                    items: filtered
                )
                
                // 选中日期的日程列表
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                                        Text(formatChineseDate(selectedDate))
                    .font(.headline)
                    .foregroundStyle(.primary)
                        Spacer()
                        Text("\(schedulesForSelectedDate.count) 个日程")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    if schedulesForSelectedDate.isEmpty {
                        Button(action: { showAdd = true }) {
                            ContentUnavailableView("当天没有日程", systemImage: "calendar.badge.plus", description: Text("点击此处添加日程"))
                                .padding()
                                .foregroundColor(.accentColor) // 修改图标颜色为亮色
                        }
                        .buttonStyle(.plain)
                    } else {
                        List {
                            ForEach(schedulesForSelectedDate) { item in
                                NavigationLink(value: item) {
                                    CalendarRow(
                                        item: item,
                                        onToggleCompletion: toggleCompletion
                                    )
                                }
                            }
                            .onDelete(perform: delete)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("萤火虫时光")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { currentMonth = Date() } label: {
                        ZStack {
                            Image(systemName: "calendar")
                            Text("📍")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.red)
                                .offset(y: -1)
                        }
                    }
                }
            }
            .navigationDestination(for: ScheduleItem.self) { item in
                AddEditViewV2(item: item, isNew: false)
            }
            .sheet(isPresented: $showAdd) {
                NavigationStack {
                    AddEditViewV2(
                        item: ScheduleItem(
                            title: "",
                            date: selectedDate
                        ),
                        isNew: true
                    )
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索标题/备注/标签")
        .task {
            do {
                try await NotificationManager.shared.requestAuthorization()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private var schedulesForSelectedDate: [ScheduleItem] {
        let calendar = Calendar.current
        return filtered.filter { item in
            calendar.isDate(item.date, inSameDayAs: selectedDate)
        }
    }
    
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let item = schedulesForSelectedDate[index]
            NotificationManager.shared.cancelNotifications(ids: item.notificationIds)
            context.delete(item)
        }
        do {
            try context.save()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func toggleCompletion(_ item: ScheduleItem) {
        item.isCompleted.toggle()
        
        if item.isCompleted {
            // 标记为完成，取消所有通知
            NotificationManager.shared.cancelNotifications(ids: item.notificationIds)
            item.notificationIds.removeAll()
        } else {
            // 标记为未完成，重新设置通知
            Task {
                do {
                    let notificationIds = try await NotificationManager.shared.scheduleNotifications(for: item)
                    item.notificationIds = notificationIds
                } catch {
                    print("重新设置通知失败: \(error.localizedDescription)")
                }
            }
        }
        
        do {
            try context.save()
        } catch {
            print("保存完成状态失败: \(error.localizedDescription)")
        }
    }
}

struct CalendarGridView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let items: [ScheduleItem]
    
    private let calendar = Calendar.current
    private let daysInWeek = ["日", "一", "二", "三", "四", "五", "六"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 月份导航
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Text(formatChineseMonth(currentMonth))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // 星期标题
            HStack(spacing: 0) {
                ForEach(daysInWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // 日历网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 1) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasSchedules: hasSchedules(for: date),
                            onTap: { selectedDate = date }
                        )
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fill)
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
    }
    
    private var daysInMonth: [Date?] {
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 30
        
        var days: [Date?] = []
        
        // 添加前一个月的日期（填充第一周）
        let previousMonthDays = firstWeekday - 1
        for _ in 0..<previousMonthDays {
            days.append(nil)
        }
        
        // 添加当前月的日期
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        // 填充到完整的周数
        let remainingDays = 7 - (days.count % 7)
        if remainingDays < 7 {
            for _ in 0..<remainingDays {
                days.append(nil)
            }
        }
        
        return days
    }
    
    private func hasSchedules(for date: Date) -> Bool {
        return items.contains { item in
            calendar.isDate(item.date, inSameDayAs: date)
        }
    }
    
    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasSchedules: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundStyle(isSelected ? .white : (isToday ? .accentColor : .primary))
                
                if hasSchedules {
                    Circle()
                        .fill(isSelected ? .white : .accentColor)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .aspectRatio(1.2, contentMode: .fill)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? .accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CalendarRow: View {
    let item: ScheduleItem
    let onToggleCompletion: (ScheduleItem) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 完成状态单选框
            Button(action: {
                onToggleCompletion(item)
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? .gray : .accentColor)
            }
            .buttonStyle(.plain)
            
            // 日程颜色标识
            Circle()
                .fill(Color(hex: item.colorHex) ?? .accentColor)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isCompleted, color: .gray)
                    .foregroundStyle(item.isCompleted ? .gray : .primary)
                
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(item.isCompleted ? .gray : .secondary)
                }
                
                Text(formatChineseTime(item.date))
                    .font(.footnote)
                    .foregroundStyle(item.isCompleted ? .gray : .secondary)
                
                if !item.tags.isEmpty {
                    HStack {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    (Color(hex: item.colorHex) ?? .accentColor)
                                        .opacity(item.isCompleted ? 0.1 : 0.15)
                                )
                                .cornerRadius(6)
                                .foregroundStyle(item.isCompleted ? .gray : .primary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(item.isCompleted ? 0.7 : 1.0)
    }
}



#Preview {
    CalendarView()
        .modelContainer(for: [ScheduleItem.self])
}
