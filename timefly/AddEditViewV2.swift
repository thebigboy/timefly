import SwiftUI
import SwiftData

struct AddEditViewV2: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var item: ScheduleItem
    let isNew: Bool  // use this to distinguish create vs edit

    @State private var wantReminder: Bool = true
    @State private var selectedPatternIndex: Int = 0
    @State private var weeklyWeekday: Int = 2
    @State private var everyN: Int = 2
    @State private var nth: Int = 2
    @State private var nthWeekday: Int = 2
    @State private var tagsInput: String = ""
    @State private var color: Color = .accentColor
    @State private var showColorPicker: Bool = false
    @FocusState private var isTitleFocused: Bool
    
    // Predefined color options
    private let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown
    ]

    let patterns: [RepeatPattern] = RepeatPattern.allCases

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("标题（必填）", text: $item.title)
                    .focused($isTitleFocused)
                // Bind String? to String
                TextField("备注", text: Binding(
                    get: { item.notes ?? "" },
                    set: { item.notes = $0.isEmpty ? nil : $0 }
                ))
            }
            Section("时间与重复") {
                DatePicker("提醒时间", selection: $item.date, displayedComponents: [.date, .hourAndMinute])
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .onAppear {
                    if isNew && item.date.timeIntervalSinceNow < 0 {
                        item.date = Date()
                    }
                }
                .foregroundColor(item.date < Calendar.current.startOfDay(for: Date()) ? .gray : .primary)

                Picker("重复", selection: $selectedPatternIndex) {
                    ForEach(patterns.indices, id: \.self) { i in Text(patterns[i].title).tag(i) }
                }

                // Show weekday picker only for weekly repeat
                if case .weekly = patterns[safe: selectedPatternIndex] ?? .none {
                    Picker("周几", selection: $weeklyWeekday) { 
                        ForEach(1...7, id: \.self) { w in 
                            Text(weekdayName(w)).tag(w) 
                        } 
                    }
                }
                Toggle("需要提醒", isOn: $wantReminder)
            }
            Section("标签与颜色") {
                TextField("标签（逗号分隔）", text: $tagsInput)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("颜色")
                        .font(.headline)
                    
                    // Preset color grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(presetColors, id: \.self) { presetColor in
                            Button(action: {
                                color = presetColor
                            }) {
                                Circle()
                                    .fill(presetColor)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(color == presetColor ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // "更多" button for custom color picker
                    Button("更多") {
                        showColorPicker = true
                    }
                    .foregroundColor(.accentColor)
                }
            }
            Section {
                Button(isNew ? "添加" : "保存修改") { Task { await save() } }
                .disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !isNew {
                    Button("删除", role: .destructive) { deleteItem() }
                }
            }
        }
        .navigationTitle(isNew ? "新增日程" : "编辑日程")
        .task { initUIState() }
        .onAppear {
            if isNew {
                // Focus on title field when creating new schedule
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFocused = true
                }
            }
        }
        .sheet(isPresented: $showColorPicker) {
            NavigationStack {
                VStack {
                    ColorPicker("选择自定义颜色", selection: $color)
                        .padding()
                    Spacer()
                }
                .navigationTitle("选择颜色")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showColorPicker = false
                        }
                    }
                }
            }
        }
    }

    private func initUIState() {
        // For new schedules, default to wanting reminder; for existing ones, use current state
        wantReminder = isNew ? true : !item.notificationIds.isEmpty
        switch item.repeatPattern {
        case .none: selectedPatternIndex = index(of: .none)
        case .daily: selectedPatternIndex = index(of: .daily)
        case .weekly(let wd): selectedPatternIndex = index(of: .weekly(weekday: 2)); weeklyWeekday = wd
        case .monthlyByDay: selectedPatternIndex = index(of: .monthlyByDay)
        //case .yearly: selectedPatternIndex = index(of: .yearly)
        // Handle legacy patterns that are no longer in the simplified list
        case .weekdays, .everyNDays, .monthlyNthWeekday: selectedPatternIndex = index(of: .none)
        }
        tagsInput = item.tags.joined(separator: ", ")
        color = Color(hex: item.colorHex) ?? .accentColor
    }

    private func save() async {
        do {
            let chosen = patterns[safe: selectedPatternIndex] ?? .none
            switch chosen {
            case .weekly: item.repeatPattern = .weekly(weekday: weeklyWeekday)
            default: item.repeatPattern = chosen
            }
            item.tags = tagsInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            item.colorHex = color.toHexString()

            if isNew { context.insert(item) }  // insert only when creating

            if wantReminder {
                let ids = try await NotificationManager.shared.scheduleNotifications(for: item)
                item.notificationIds = ids
            } else {
                NotificationManager.shared.cancelNotifications(ids: item.notificationIds)
                item.notificationIds.removeAll()
            }
            try context.save()
            dismiss()
        } catch { print("保存失败: \(error)") }
    }

    private func deleteItem() {
        NotificationManager.shared.cancelNotifications(ids: item.notificationIds)
        context.delete(item)
        do { try context.save() } catch { print(error.localizedDescription) }
        dismiss()
    }

    private func index(of pattern: RepeatPattern) -> Int { patterns.firstIndex { $0.title == pattern.title } ?? 0 }
    private func weekdayName(_ v: Int) -> String { ["周日","周一","周二","周三","周四","周五","周六"][max(1,min(7,v))-1] }
}

extension Collection { subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil } }
