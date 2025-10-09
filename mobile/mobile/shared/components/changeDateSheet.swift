//
//  changeDateSheet.swift
//  mobile
//
//  Created by 이채린 on 8/24/25.
//

import SwiftUI

public struct ChangeDateSheet: View {
    public let initialDate: Date
    public var onConfirm: (Date) -> Void
    public var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pickedDate: Date
    
    // Calendar states for custom UI
    @State private var currentMonthAnchor: Date      = Date()      // month being displayed
    @State private var showMonthDropdown: Bool       = false       // dropdown toggle

    private let calendar = Calendar.current
    private let columns  = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let years    = Array(2010...2035)
    private let months   = Array(1...12)

    // MARK: - Init
    public init(
        initialDate: Date,
        onConfirm: @escaping (Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialDate = initialDate
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _pickedDate = State(initialValue: initialDate)
    }

    // MARK: - Body
    public var body: some View {
        ZStack {
            ZStack {
                DarkBlurView(style: .systemChromeMaterialDark)
                    .ignoresSafeArea()

                Color.black.opacity(0.5)
                    .ignoresSafeArea()

            }
            .contentShape(Rectangle())
            .onTapGesture { onCancel() } // tap outside to close

            // Card
            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    Text("Change Date")
                        .appFont(AppFont.title3)
                        .foregroundColor(Color("White"))
                    Spacer()
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(Color("White"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 21)
                .padding(.leading, 25)
                .padding(.trailing, 23)
                
                // --- divider ---
                Divider()
                    .frame(width: 329)
                    .background(Color("Neutral-800"))
                    .padding(.top, 18)

                // MARK: Calendar (custom)
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

                    VStack{
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
                            dropdownPicker
                                .zIndex(10)
                                .shadow(radius: 12)
                        }
                    }
                    .zIndex(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // MARK: Confirm button
                Button {
                    onConfirm(pickedDate)
                } label: {
                    Text("Confirm")
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .appFont(AppFont.title3)
                        .foregroundColor(.black)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color("Green-300"))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .frame(width: 361, height: 491) //h: 451
            .background( // of the card
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.black)).opacity(0.5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            )
            .overlay(
                // stroke
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color("Neutral-400").opacity(0.7),
                                Color("Neutral-600").opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 14)
        }
        .navBarHidden(true)
        .onChange(of: currentMonthAnchor) { _ in
            // Keep pickedDate in visible month if it was outside after month change
            if !calendar.isDate(pickedDate, equalTo: currentMonthAnchor, toGranularity: .month) {
                // snap to first day of new month, or preserve day if possible
                let day = min(calendar.component(.day, from: pickedDate),
                              calendar.range(of: .day, in: .month, for: currentMonthAnchor)?.count ?? 1)
                pickedDate = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: currentMonthAnchor),
                    month: calendar.component(.month, from: currentMonthAnchor),
                    day: day
                )) ?? currentMonthAnchor
            }
        }
    }
    // MARK: - Dropdown Picker (inline overlay)
    private var dropdownPicker: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.neutral900.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.neutral700, lineWidth: 1)
                )

            HStack(spacing: 0) {
                // Month wheel
                Picker("Month", selection: Binding(
                    get: { calendar.component(.month, from: currentMonthAnchor) },
                    set: { newMonth in
                        currentMonthAnchor = calendar.date(from: DateComponents(
                            year: calendar.component(.year, from: currentMonthAnchor),
                            month: newMonth, day: 1)) ?? currentMonthAnchor
                    }
                )) {
                    ForEach(months, id: \.self) { m in
                        Text(monthName(m))
                            .appFont(AppFont.labelM)
                            .foregroundColor(.white)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity, minHeight: 150)

                // Year wheel
                Picker("Year", selection: Binding(
                    get: { calendar.component(.year, from: currentMonthAnchor) },
                    set: { newYear in
                        currentMonthAnchor = calendar.date(from: DateComponents(
                            year: newYear,
                            month: calendar.component(.month, from: currentMonthAnchor),
                            day: 1
                        )) ?? currentMonthAnchor
                    }
                )) {
                    ForEach(years, id: \.self) { y in
                        Text(String(y))
                            .appFont(AppFont.labelM)
                            .foregroundColor(.white)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity, minHeight: 150)
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 170)
    }

    // MARK: - Day Cell
    private func dayCell(for day: Date) -> some View {
        let isInCurrentMonth = calendar.isDate(day, equalTo: currentMonthAnchor, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: pickedDate)
        let isToday = calendar.isDateInToday(day)

        return Button {
            pickedDate = day
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
                            isToday
                            ? .green300
                            : (isInCurrentMonth
                               ? .neutral400
                               : .neutral800)
                        )
                        .frame(width: 36, height: 36)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .center)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers
    private func moveMonth(by value: Int) {
        if let d = calendar.date(byAdding: .month, value: value, to: currentMonthAnchor) {
            currentMonthAnchor = calendar.startOfMonth(for: d)
        }
    }

    private func daysGrid() -> [Date] {
        // Build a 6x7 grid including previous/next month spillover
        let start = calendar.startOfMonth(for: currentMonthAnchor)
        let range = calendar.range(of: .day, in: .month, for: start)!
        let firstWeekday = calendar.component(.weekday, from: start) // 1...7 (Sun=1)
        let leading = (firstWeekday + 6) % 7 // number of days from previous month

        // previous month tail
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: start)!
        let prevCount = calendar.range(of: .day, in: .month, for: prevMonth)!.count
        var days: [Date] = (prevCount - leading + 1...prevCount).compactMap { day -> Date? in
            calendar.date(from: DateComponents(
                year: calendar.component(.year, from: prevMonth),
                month: calendar.component(.month, from: prevMonth),
                day: day
            ))
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
        // SUN ... SAT (uppercase)
        let syms = calendar.shortStandaloneWeekdaySymbols
        return syms.map { $0.uppercased() }
    }

    private func formattedYYYYMM(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM"
        return f.string(from: date)
    }

    private func monthName(_ m: Int) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.monthSymbols[m - 1]
    }
}
