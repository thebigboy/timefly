import SwiftUI
import SwiftData

@main
struct SchedulesAppV2: App {
    init() {
        NotificationManager.shared.configureCategories()
    }
    var body: some Scene {
        WindowGroup { CalendarView() }
            .modelContainer(for: [ScheduleItem.self])
    }
}
