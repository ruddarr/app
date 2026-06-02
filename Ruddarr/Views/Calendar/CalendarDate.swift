import SwiftUI

enum CalendarDateStyle {
    case rich
    case classic
}

struct CalendarDate: View {
    var date: Date
    var style: CalendarDateStyle = .rich

    @State var isToday: Bool = false

    @EnvironmentObject var settings: AppSettings

    @ViewBuilder
    var body: some View {
        Group {
            switch style {
            case .rich:
                richDate
            case .classic:
                classicDate
            }
        }
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

    var richDate: some View {
        HStack {
            dateLockup

            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var dateLockup: some View {
        HStack(alignment: .center, spacing: 7) {
            VStack(alignment: .leading, spacing: 0) {
                Text(CalendarDate.dayOfWeek.string(from: date).uppercased())
                    .font(.caption2.weight(.semibold))
                    .kerning(1.05)
                    .lineLimit(1)
                    .offset(y: 1)

                Text(CalendarDate.nameOfMonth.string(from: date).uppercased())
                    .font(.caption2)
                    .kerning(1.05)
                    .lineLimit(1)
            }
            .foregroundStyle(isToday ? settings.theme.tint : .secondary)

            Text(CalendarDate.dayOfMonth.string(from: date))
                .font(.title.bold())
                .monospacedDigit()
                .foregroundStyle(isToday ? settings.theme.tint : .primary)
        }
        .fixedSize()
        .padding(.vertical, 4)
        .padding(.horizontal, 7)
        .background(.background.opacity(0.8), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .offset(x: -7)
    }

    var classicDate: some View {
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
    var style: CalendarDateStyle = .rich

    @ViewBuilder
    var body: some View {
        switch style {
        case .rich:
            Text(weekRange(date))
                .font(.subheadline)
                .textCase(.uppercase)
                .kerning(1.0)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .padding(.bottom, 6)
        case .classic:
            Text(weekRange(date))
                .font(.subheadline)
                .textCase(.uppercase)
                .kerning(1.0)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
                .padding(.leading, 1)
        }
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
