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

    let patterns: [RepeatPattern] = RepeatPattern.allCases

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("标题（必填）", text: $item.title)
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
                .foregroundColor(item.date < Date() ? .gray : .primary)

                Picker("重复", selection: $selectedPatternIndex) {
                    ForEach(patterns.indices, id: \.self) { i in Text(patterns[i].title).tag(i) }
                }

                Group {
                    if case .weekly = patterns[safe: selectedPatternIndex] ?? .none {
                        Picker("周几", selection: $weeklyWeekday) { ForEach(1...7, id: \.self) { w in Text(weekdayName(w)).tag(w) } }
                    }
                    if case .everyNDays = patterns[safe: selectedPatternIndex] ?? .none {
                        Stepper(value: $everyN, in: 2...30) { Text("间隔天数：\(everyN)") }
                    }
                    if case .monthlyNthWeekday = patterns[safe: selectedPatternIndex] ?? .none {
                        Stepper(value: $nth, in: 1...5) { Text("第几周：\(nth)") }
                        Picker("周几", selection: $nthWeekday) { ForEach(1...7, id: \.self) { w in Text(weekdayName(w)).tag(w) } }
                    }
                }
                Toggle("需要提醒", isOn: $wantReminder)
                .onAppear {
                    wantReminder = true
                }
            }
            Section("标签与颜色") {
                TextField("标签（逗号分隔）", text: $tagsInput)
                ColorPicker("颜色", selection: $color)
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
    }

    private func initUIState() {
        wantReminder = !item.notificationIds.isEmpty
        switch item.repeatPattern {
        case .none: selectedPatternIndex = index(of: .none)
        case .daily: selectedPatternIndex = index(of: .daily)
        case .weekly(let wd): selectedPatternIndex = index(of: .weekly(weekday: 2)); weeklyWeekday = wd
        case .weekdays: selectedPatternIndex = index(of: .weekdays)
        case .everyNDays(let n): selectedPatternIndex = index(of: .everyNDays(n: 2)); everyN = n
        case .monthlyByDay: selectedPatternIndex = index(of: .monthlyByDay)
        case .monthlyNthWeekday(let n, let wd): selectedPatternIndex = index(of: .monthlyNthWeekday(nth: 2, weekday: 2)); nth = n; nthWeekday = wd
        }
        tagsInput = item.tags.joined(separator: ", ")
        color = Color(hex: item.colorHex) ?? .accentColor
    }

    private func save() async {
        do {
            let chosen = patterns[safe: selectedPatternIndex] ?? .none
            switch chosen {
            case .weekly: item.repeatPattern = .weekly(weekday: weeklyWeekday)
            case .everyNDays: item.repeatPattern = .everyNDays(n: everyN)
            case .monthlyNthWeekday: item.repeatPattern = .monthlyNthWeekday(nth: nth, weekday: nthWeekday)
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
