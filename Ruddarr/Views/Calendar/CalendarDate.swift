import SwiftUI

struct CalendarDate: View {
    var date: Date

    @State var isToday: Bool = false

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text(CalendarDate.dayOfWeek.string(from: date).uppercased())
                .font(.caption2)
                .kerning(1.05)
                .lineLimit(1)
                .foregroundStyle(isToday ? .primary : .secondary)
                .offset(y: 3)

            Text(CalendarDate.dayOfMonth.string(from: date))
                .font(.title)

            Text(CalendarDate.nameOfMonth.string(from: date).uppercased())
                .font(.caption2)
                .kerning(1.05)
                .lineLimit(1)
                .foregroundStyle(isToday ? .primary : .secondary)
                .offset(y: -3)

            Spacer()
        }
        .foregroundStyle(isToday ? settings.theme.tint : .primary)
        .onAppear {
            isToday = Calendar.current.isDateInToday(date)
        }
        .onBecomeActive {
            isToday = Calendar.current.isDateInToday(date)
        }
        .transaction { transaction in
            transaction.animation = nil // disable animation
        }
    }

    static let dayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()

    static let dayOfMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    static let nameOfMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
}

struct CalendarWeekRange: View {
    var date: Date

    var body: some View {
        Spacer()

        Text(weekRange(date))
            .font(.subheadline)
            .textCase(.uppercase)
            .kerning(1.0)
            .foregroundStyle(.secondary)
            .padding(.bottom, 12)
            .padding(.leading, 1)
    }

    func weekRange(_ date: Date) -> String {
        let calendar = Calendar.current

        guard let endDate = calendar.date(byAdding: .day, value: 6, to: date) else {
            return "Date range error"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d"

        let startFormat = dateFormatter.string(from: date)

        if calendar.isDate(date, equalTo: endDate, toGranularity: .month) {
            dateFormatter.dateFormat = "d"
        }

        let endFormat = dateFormatter.string(from: endDate)

        return "\(startFormat) – \(endFormat)"
    }
}

#Preview {
    dependencies.router.selectedTab = .calendar

    return ContentView()
        .withAppState()
}
