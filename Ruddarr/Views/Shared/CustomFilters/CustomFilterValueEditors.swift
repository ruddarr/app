import SwiftUI

/// One or more free-form text, number or size values, stored as an array.
struct CustomFilterListValueEditor: View {
    let kind: CustomFilterValueKind
    /// `false` for comparisons such as "is above", where a second value is meaningless.
    let allowsMultiple: Bool
    /// Whether the field's values are on a 0–100 scale, shown in the placeholder.
    let isPercentScale: Bool
    @Binding var value: CustomFilterValue

    @State private var entries: [Entry]

    struct Entry: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var unit: CustomFilterByteUnit = .gigabytes
    }

    init(kind: CustomFilterValueKind, allowsMultiple: Bool, isPercentScale: Bool, value: Binding<CustomFilterValue>) {
        self.kind = kind
        self.allowsMultiple = allowsMultiple
        self.isPercentScale = isPercentScale
        self._value = value

        let entries = value.wrappedValue.arrayValues.compactMap { Self.entry(for: $0, kind: kind) }
        self._entries = State(initialValue: entries.isEmpty ? [Entry(text: "")] : entries)
    }

    var body: some View {
        ForEach($entries) { $entry in
            HStack {
                TextField(prompt, text: $entry.text, prompt: Text(prompt))
                    .labelsHidden()
                    #if os(iOS)
                        .keyboardType(kind == .text ? .default : .decimalPad)
                        .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                if kind == .bytes {
                    Picker("Unit", selection: $entry.unit) {
                        ForEach(CustomFilterByteUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                if entries.count > 1 {
                    Button("Remove Value", systemImage: "minus.circle.fill", role: .destructive) {
                        entries.removeAll { $0.id == entry.id }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }
            // On every row, as at least one row always remains.
            .onChange(of: entries) {
                value = .array(entries.compactMap(parse))
            }
        }

        if allowsMultiple {
            Button("Add Value", systemImage: "plus") {
                entries.append(Entry(text: "", unit: entries.last?.unit ?? .gigabytes))
            }
        }
    }

    var prompt: String {
        switch kind {
        case .bytes: String(localized: "Size")
        case .number where isPercentScale: String(localized: "Number (0–100)")
        case .number: String(localized: "Number")
        default: String(localized: "Value")
        }
    }

    func parse(_ entry: Entry) -> CustomFilterValue? {
        let text = entry.text.trimmed()
        guard !text.isEmpty else { return nil }

        if kind == .text {
            return .string(text)
        }

        guard let number = Double(text.replacingOccurrences(of: ",", with: ".")), number.isFinite else {
            return nil
        }

        if kind == .bytes {
            return .int(Int((number * entry.unit.multiplier).rounded()))
        }

        if number == number.rounded(), let int = Int(exactly: number) {
            return .int(int)
        }

        return .double(number)
    }

    static func entry(for value: CustomFilterValue, kind: CustomFilterValueKind) -> Entry? {
        switch kind {
        case .bytes:
            guard let bytes = value.doubleValue else { return nil }
            let unit = CustomFilterByteUnit.unit(for: bytes)
            let amount = bytes / unit.multiplier
            return Entry(text: amount.formatted(.number.grouping(.never).precision(.fractionLength(0...2))), unit: unit)
        case .number:
            guard let number = value.doubleValue else { return nil }
            return Entry(text: number.formatted(.number.grouping(.never).precision(.fractionLength(0...6))))
        default:
            return Entry(text: value.rawText)
        }
    }
}

/// A date value: a `"yyyy-mm-dd"` string for before/after, or `{ time, value }` for in/not in last/next.
struct CustomFilterDateValueEditor: View {
    let isRelative: Bool
    @Binding var value: CustomFilterValue

    var body: some View {
        if isRelative {
            LabeledContent("Amount") {
                TextField("Amount", value: amountBinding, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
            }

            Picker("Unit", selection: unitBinding) {
                ForEach(CustomFilterTimeUnit.allCases) { unit in
                    Text(unit.label).tag(unit)
                }
            }
        } else {
            DatePicker("Date", selection: dateBinding, displayedComponents: .date)
        }
    }

    var dateBinding: Binding<Date> {
        Binding(
            get: {
                guard case .string(let string) = value else { return .now }
                return CustomFilterDate.date(from: string) ?? .now
            },
            set: { value = .string(CustomFilterDate.string(from: $0)) }
        )
    }

    var object: [String: CustomFilterValue] {
        if case .object(let object) = value { return object }
        return [:]
    }

    var amountBinding: Binding<Int?> {
        Binding(
            get: { object["value"]?.intValue },
            set: { amount in
                var object = object
                object["value"] = amount.map { .int(max(0, $0)) } ?? .null
                object["time"] = object["time"] ?? .string(CustomFilterTimeUnit.days.rawValue)
                value = .object(object)
            }
        )
    }

    var unitBinding: Binding<CustomFilterTimeUnit> {
        Binding(
            get: {
                guard case .string(let raw) = object["time"] else { return .days }
                return CustomFilterTimeUnit(rawValue: raw) ?? .days
            },
            set: { unit in
                var object = object
                object["time"] = .string(unit.rawValue)
                object["value"] = object["value"] ?? .null
                value = .object(object)
            }
        )
    }
}
