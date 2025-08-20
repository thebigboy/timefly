import SwiftUI
import SwiftData

struct ContentViewV2: View {
    @Environment(\.modelContext) private var context
    @Query private var items: [ScheduleItem]
    @State private var showAdd = false
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
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView("没有匹配的日程", systemImage: "calendar", description: Text("试试添加或调整搜索/标签过滤"))
                } else {
                    List {
                        if !allTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    TagChip(text: "全部", isSelected: selectedTag == nil) { selectedTag = nil }
                                    ForEach(allTags, id: \.self) { t in
                                        TagChip(text: t, isSelected: selectedTag == t) { selectedTag = (selectedTag == t ? nil : t) }
                                    }
                                }.padding(.vertical, 4)
                            }
                        }
                        ForEach(filtered) { item in
                            NavigationLink(value: item) { 
                                Row(
                                    item: item,
                                    onToggleCompletion: toggleCompletion
                                ) 
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("萤火虫时光")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
            .navigationDestination(for: ScheduleItem.self) { item in AddEditViewV2(item: item, isNew: false) }
            .sheet(isPresented: $showAdd) { NavigationStack { AddEditViewV2(item: ScheduleItem(title: "", date: .now.addingTimeInterval(3600)), isNew: true) } }
        }
        .task { do { try await NotificationManager.shared.requestAuthorization() } catch { print(error.localizedDescription) } }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索标题/备注/标签")
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            NotificationManager.shared.cancelNotifications(ids: filtered[index].notificationIds)
            context.delete(filtered[index])
        }
        do { try context.save() } catch { print(error.localizedDescription) }
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

struct Row: View {
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
            Circle().fill(Color(hex: item.colorHex) ?? .accentColor).frame(width: 10, height: 10)
            
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
                
                Text(formatChineseDateTimeForRow(item.date))
                    .font(.footnote)
                    .foregroundStyle(item.isCompleted ? .gray : .secondary)
                
                if !item.tags.isEmpty {
                    HStack { 
                        ForEach(item.tags, id: \.self) { t in 
                            Text(t)
                                .font(.caption2)
                                .padding(.horizontal,6)
                                .padding(.vertical,2)
                                .background((Color(hex: item.colorHex) ?? .accentColor).opacity(item.isCompleted ? 0.1 : 0.15))
                                .cornerRadius(6)
                                .foregroundStyle(item.isCompleted ? .gray : .primary)
                        } 
                    }
                }
            }
            
            Spacer()
        }
        .opacity(item.isCompleted ? 0.7 : 1.0)
    }
    
    // MARK: - 中文日期时间格式化
    
    private func formatChineseDateTimeForRow(_ date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        let monthNames = [
            1: "1月", 2: "2月", 3: "3月", 4: "4月", 5: "5月", 6: "6月",
            7: "7月", 8: "8月", 9: "9月", 10: "10月", 11: "11月", 12: "12月"
        ]
        
        let hourStr = hour < 10 ? "0\(hour)" : "\(hour)"
        let minuteStr = minute < 10 ? "0\(minute)" : "\(minute)"
        
        return "\(monthNames[month] ?? "\(month)月")\(day)日 \(hourStr):\(minuteStr)"
    }
}

struct TagChip: View {
    let text: String
    let isSelected: Bool
    var onTap: () -> Void
    var body: some View {
        Text(text).font(.caption)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSelected ? Color.secondary.opacity(0.25) : Color.secondary.opacity(0.12))
            .cornerRadius(8)
            .onTapGesture { onTap() }
    }
}
