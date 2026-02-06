//
//  customCalendar.swift
//  mobile
//
//  Created by Kristie Lee on 10/9/25.
//

import SwiftUI

public struct CustomCalendar: View {
    // --- Public API ---
    @Binding public var selectedDate: Date
    public var lowerBound: Date? = nil
    public var upperBound: Date? = nil

    // --- Internal States ---
    @State private var currentMonthAnchor: Date = Date()      // month being displayed
    @State private var showMonthDropdown: Bool = false        // dropdown toggle
    
    // --- Constants copied from the sheet design ---
    private let calendar = Calendar.current
    private let columns  = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let years    = Array(2010...2035)
    private let months   = Array(1...12)

    public init(selectedDate: Binding<Date>, lowerBound: Date? = nil, upperBound: Date? = nil) {
        self._selectedDate = selectedDate
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public var body: some View {
        // --- This VStack matches the calendar block in your changeDateSheet ---
        VStack {
            // Month-Year row (dropdown + month move)
            HStack {
                Button {
                    showMonthDropdown.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(formattedYYYYMM(currentMonthAnchor))
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

            VStack {
                // Weekday header
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
                    MonthYearDropdown(anchorMonth: $currentMonthAnchor)
                        .frame(width:240)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(10)
                }
            }
            .zIndex(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .onChange(of: currentMonthAnchor) { _ in
            // Keep selectedDate in visible month if it was outside after month change
            if !calendar.isDate(selectedDate, equalTo: currentMonthAnchor, toGranularity: .month) {
                let day = min(calendar.component(.day, from: selectedDate),
                              calendar.range(of: .day, in: .month, for: currentMonthAnchor)?.count ?? 1)
                var new = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: currentMonthAnchor),
                    month: calendar.component(.month, from: currentMonthAnchor),
                    day: day
                )) ?? currentMonthAnchor
                // clamp by bounds if provided
                if let lo = lowerBound, new < startOfDay(lo) { new = startOfDay(lo) }
                if let hi = upperBound, new > startOfDay(hi) { new = startOfDay(hi) }
                selectedDate = new
            }
        }
    }

    // MARK: - Day Cell (same colors/size/spacing, + bounds handling)
    private func dayCell(for day: Date) -> some View {
        let isInCurrentMonth = calendar.isDate(day, equalTo: currentMonthAnchor, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let clamped = isSelectable(day)

        return Button {
            if clamped { selectedDate = day }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(.green300)
                        .frame(width: 36, height: 36)
                    Text("\(calendar.component(.day, from: day))")
                        .appFont(AppFont.labelM)
                        .foregroundColor(.black)
                } else {
                    Text("\(calendar.component(.day, from: day))")
                        .appFont(AppFont.labelM)
                        .foregroundColor(
                            clamped == false
                            ? .neutral800                   // out of allowed range looks disabled
                            : (isToday
                               ? .green300                 // today
                               : (isInCurrentMonth
                                  ? .neutral400           // current month
                                  : .neutral800))         // prev/next month
                        )
                        .frame(width: 36, height: 36)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .center)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(!clamped)
    }

    // MARK: - Helpers
    private func isSelectable(_ d: Date) -> Bool {
        let d0 = startOfDay(d)
        if let lo = lowerBound, d0 < startOfDay(lo) { return false }
        if let hi = upperBound, d0 > startOfDay(hi) { return false }
        return true
    }
    private func moveMonth(by value: Int) {
        if let d = calendar.date(byAdding: .month, value: value, to: currentMonthAnchor) {
            currentMonthAnchor = calendar.startOfMonth(for: d)
        }
    }
    private func daysGrid() -> [Date] {
        let start = calendar.startOfMonth(for: currentMonthAnchor)
        let range = calendar.range(of: .day, in: .month, for: start)!
        let firstWeekday = calendar.component(.weekday, from: start) // 1...7 (Sun=1)
        let leading = (firstWeekday + 6) % 7

        // prev month tail
        guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: start),
              let prevRange = calendar.range(of: .day, in: .month, for: prevMonth)
        else {
            return []
        }

        let prevCount = prevRange.count

        var days: [Date] = []

        // Only create the prev tail if leading > 0
        if leading > 0 {
            let startDay = prevCount - leading + 1
            if startDay <= prevCount {
                days = (startDay...prevCount).compactMap { day -> Date? in
                    calendar.date(from: DateComponents(
                        year: calendar.component(.year, from: prevMonth),
                        month: calendar.component(.month, from: prevMonth),
                        day: day
                    ))
                }
            }
        }

        // current month
        days += range.compactMap { day -> Date? in
            calendar.date(from: DateComponents(
                year: calendar.component(.year, from: start),
                month: calendar.component(.month, from: start),
                day: day
            ))
        }

        // next month head to fill 42 cells
        let remaining = max(0, 42 - days.count)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: start)!
        if remaining > 0 {
            days += (1...remaining).compactMap { day -> Date? in
                calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: nextMonth),
                    month: calendar.component(.month, from: nextMonth),
                    day: day
                ))
            }
        }
        return days
    }
    private func weekdaySymbols() -> [String] {
        let syms = calendar.shortStandaloneWeekdaySymbols
        return syms.map { $0.uppercased() }
    }
    private func formattedYYYYMM(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM"
        return f.string(from: date)
    }
    private func monthName(_ m: Int) -> String {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX")
        return df.monthSymbols[m - 1]
    }
    private func startOfDay(_ d: Date) -> Date { calendar.startOfDay(for: d) }
}
