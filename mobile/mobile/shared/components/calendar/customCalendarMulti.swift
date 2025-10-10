//
//  customCalendarMulti.swift
//  mobile
//
//  Created by Kristie Lee on 10/10/25.
//
import SwiftUI

public struct CustomCalendarMulti: View {
    // MARK: - Public API
    @Binding public var monthAnchor: Date                 // which month to display
    @Binding public var selectedDays: Set<Int>            // 1...31 (days-of-month)
    public var lowerBound: Date? = nil                    // optional: min date (inclusive)
    public var upperBound: Date? = nil                    // optional: max date (inclusive)

    // MARK: - Internal States
    @State private var showMonthDropdown: Bool = false

    // MARK: - Constants (mirrors CustomCalendar)
    private let calendar = Calendar.current
    private let columns  = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    public init(
        monthAnchor: Binding<Date>,
        selectedDays: Binding<Set<Int>>,
        lowerBound: Date? = nil,
        upperBound: Date? = nil
    ) {
        self._monthAnchor = monthAnchor
        self._selectedDays = selectedDays
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public var body: some View {
        VStack {
            // --- Month-Year row (dropdown + month move) ---
            HStack {
                Button {
                    withAnimation(.easeInOut) { showMonthDropdown.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(formattedYYYYMM(monthAnchor))
                            .appFont(AppFont.labelM)
                            .foregroundColor(.white)
                        Image(systemName: showMonthDropdown ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 18) {
                    Button { moveMonth(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.neutral400)
                    }
                    Button { moveMonth(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.neutral400)
                    }
                }
            }
            .padding(.horizontal, 16)

            // --- Grid area (weekday header + 6x7 cells) ---
            VStack {
                // Weekday header (SUN..SAT)
                HStack {
                    ForEach(weekdaySymbols(), id: \.self) { w in
                        Text(w)
                            .appFont(AppFont.captionXS)
                            .foregroundColor(.neutral50)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.top, 12)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(daysGrid(), id: \.self) { day in
                        dayCell(for: day)
                    }
                }
            }
            .padding(.horizontal, 16)
            .overlay(alignment: .topLeading) {
                if showMonthDropdown {
                    // Reuse the same dropdown used by CustomCalendar (already in project)
                    MonthYearDropdown(anchorMonth: $monthAnchor)
                        .frame(width: 240)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(10)
                }
            }
            .zIndex(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Day Cell (multi-select)
    private func dayCell(for day: Date) -> some View {
        let inCurrentMonth = calendar.isDate(day, equalTo: monthAnchor, toGranularity: .month)
        let dayNum = calendar.component(.day, from: day)
        let isToday = calendar.isDateInToday(day)
        let withinBounds = isSelectable(day)
        let isSelected = inCurrentMonth && withinBounds && selectedDays.contains(dayNum)

        return Button {
            guard inCurrentMonth && withinBounds else { return }
            if selectedDays.contains(dayNum) {
                selectedDays.remove(dayNum)
            } else {
                selectedDays.insert(dayNum)
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(.green300)
                        .frame(width: 36, height: 36)
                    Text("\(dayNum)")
                        .appFont(AppFont.labelM)
                        .foregroundColor(.black)
                } else {
                    Text("\(dayNum)")
                        .appFont(AppFont.labelM)
                        .foregroundColor(
                            withinBounds
                                ? (inCurrentMonth
                                   ? (isToday ? .green300 : .neutral400)
                                   : .neutral800)
                                : .neutral800
                        )
                        .frame(width: 36, height: 36)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .center)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(!(inCurrentMonth && withinBounds))
        .accessibilityLabel("Day \(dayNum)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Helpers (same logic style as CustomCalendar)
    private func daysGrid() -> [Date] {
        let start = startOfMonth(monthAnchor)
        let range = calendar.range(of: .day, in: .month, for: start)!
        let firstWeekday = calendar.component(.weekday, from: start) // 1...7 (Sun=1)
        let leading = (firstWeekday + 6) % 7

        // prev month tail
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: start)!
        let prevCount = calendar.range(of: .day, in: .month, for: prevMonth)!.count
        var days: [Date] = (prevCount - leading + 1...prevCount).compactMap { d in
            date(year: year(prevMonth), month: month(prevMonth), day: d)
        }

        // current month
        days += range.compactMap { d in
            date(year: year(start), month: month(start), day: d)
        }

        // next month head to fill 42 cells
        let remaining = max(0, 42 - days.count)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: start)!
        if remaining > 0 {
            days += (1...remaining).compactMap { d in
                date(year: year(nextMonth), month: month(nextMonth), day: d)
            }
        }
        return days
    }

    private func isSelectable(_ d: Date) -> Bool {
        let d0 = calendar.startOfDay(for: d)
        if let lo = lowerBound, d0 < calendar.startOfDay(for: lo) { return false }
        if let hi = upperBound, d0 > calendar.startOfDay(for: hi) { return false }
        return true
    }

    private func moveMonth(by value: Int) {
        if let d = calendar.date(byAdding: .month, value: value, to: monthAnchor) {
            // If you already have an extension `startOfMonth(for:)`, you can keep using it.
            monthAnchor = startOfMonth(d)
        }
    }

    // --- Small utils
    private func formattedYYYYMM(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM"
        return f.string(from: date)
    }
    private func weekdaySymbols() -> [String] {
        calendar.shortStandaloneWeekdaySymbols.map { $0.uppercased() }
    }
    private func startOfMonth(_ d: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: d)
        return calendar.date(from: comps) ?? d
    }
    private func date(year: Int, month: Int, day: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
    private func year(_ d: Date) -> Int { calendar.component(.year, from: d) }
    private func month(_ d: Date) -> Int { calendar.component(.month, from: d) }
}
