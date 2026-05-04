//
//  changeDateSheet.swift
//  mobile
//
//  Created by 이채린 on 8/24/25.
//

import SwiftUI

enum ChangeDateSheetCalendarStyle {
    case standard
    case tracker
}

struct ChangeDateSheet: View {
    let initialDate: Date
    let calendarStyle: ChangeDateSheetCalendarStyle
    let shakerRecords: [String: ShakerRecord]
    var onConfirm: (Date) -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pickedDate: Date
    @State private var trackerDisplayedMonth: Date

    init(
        initialDate: Date,
        calendarStyle: ChangeDateSheetCalendarStyle = .standard,
        shakerRecords: [String: ShakerRecord] = [:],
        onConfirm: @escaping (Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialDate = initialDate
        self.calendarStyle = calendarStyle
        self.shakerRecords = shakerRecords
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _pickedDate = State(initialValue: initialDate)
        _trackerDisplayedMonth = State(initialValue: Calendar.current.startOfMonth(for: initialDate))
    }

    private var trackerCardHeight: CGFloat {
        // Base height fits 5 rows; each extra/missing row adjusts by one row's grid pitch.
        let baseHeight: CGFloat = 470
        let rowPitch: CGFloat = 58 // 46pt cell + 12pt LazyVGrid spacing
        let rows = ChangeDateSheet.numberOfWeeks(in: trackerDisplayedMonth)
        return baseHeight + CGFloat(rows - 5) * rowPitch
    }

    private static func numberOfWeeks(in month: Date) -> Int {
        let calendar = Calendar.current
        let firstOfMonth = calendar.startOfMonth(for: month)
        guard let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return 5 }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        let totalCells = leadingEmptyDays + range.count
        return Int(ceil(Double(totalCells) / 7.0))
    }

    var body: some View {
        GeometryReader { geo in
            let cardWidth = max(0, geo.size.width - 32)
            let dividerWidth = max(0, cardWidth - 42)

            ZStack {
                ZStack {
                    DarkBlurView(style: .systemChromeMaterialDark)
                        .ignoresSafeArea()

                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                }
                .contentShape(Rectangle())
                .onTapGesture { onCancel() }

                VStack(spacing: 0) {
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
                    .padding(.horizontal, 21)

                    Divider()
                        .frame(width: dividerWidth)
                        .background(Color("Neutral-800"))
                        .padding(.top, 18)

                    Group {
                        switch calendarStyle {
                        case .standard:
                            CustomCalendar(selectedDate: $pickedDate)
                        case .tracker:
                            TrackerStyleCalendar(
                                selectedDate: $pickedDate,
                                displayedMonth: $trackerDisplayedMonth,
                                shakerRecords: shakerRecords,
                                onDateSelected: { date in
                                    onConfirm(date)
                                }
                            )
                        }
                    }

                    if calendarStyle == .standard {
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
                    } else {
                        Spacer().frame(height: 24)
                    }
                }
                .frame(width: cardWidth, height: calendarStyle == .tracker ? trackerCardHeight : 491)
                .animation(.easeInOut(duration: 0.2), value: trackerCardHeight)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.black)).opacity(0.5)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                )
                .overlay(
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navBarHidden(true)
    }
}

private struct TrackerStyleCalendar: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date
    let shakerRecords: [String: ShakerRecord]
    let onDateSelected: (Date) -> Void

    @State private var showMonthDropdown = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols

    init(
        selectedDate: Binding<Date>,
        displayedMonth: Binding<Date>,
        shakerRecords: [String: ShakerRecord],
        onDateSelected: @escaping (Date) -> Void
    ) {
        self._selectedDate = selectedDate
        self._displayedMonth = displayedMonth
        self.shakerRecords = shakerRecords
        self.onDateSelected = onDateSelected
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showMonthDropdown.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(formattedMonthYear(displayedMonth))
                            .appFont(AppFont.title3)
                            .foregroundColor(Color("White"))

                        Image(systemName: showMonthDropdown ? "chevron.up" : "chevron.down")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 9, height: 9)
                            .foregroundColor(Color("White"))
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 23)

                Spacer()

                Button(action: { moveMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color("Neutral-400"))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)

                Button(action: { moveMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color("Neutral-400"))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 21)
            }
            .padding(.top, 18)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day.uppercased())
                        .appFont(AppFont.captionXS)
                        .foregroundColor(Color("Neutral-50"))
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button(action: {
                            selectedDate = date
                            onDateSelected(date)
                        }) {
                            VStack {
                                ShakerBarView(
                                    shakerRecord: shakerRecords[formattedDate(date)]
                                )
                                ZStack {
                                    if calendar.isDate(date, inSameDayAs: selectedDate) {
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(Color("Green-300"))
                                            .frame(width: 26, height: 14)

                                        Text("\(calendar.component(.day, from: date))")
                                            .appFont(AppFont.captionXS_M)
                                            .foregroundColor(Color("Neutral-1000"))
                                    } else {
                                        Text("\(calendar.component(.day, from: date))")
                                            .appFont(AppFont.captionXS_M)
                                            .foregroundColor(Color("Neutral-400"))
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 46)
                    }
                }
            }
            .padding(.top, 23)
            .padding(.horizontal, 16)
            .overlay(alignment: .topLeading) {
                if showMonthDropdown {
                    MonthYearDropdown(anchorMonth: $displayedMonth)
                        .frame(width: 240)
                        .padding(.leading, 16)
                        .padding(.top, 8)
                        .opacity(showMonthDropdown ? 1 : 0)
                        .allowsHitTesting(showMonthDropdown)
                        .zIndex(10)
                }
            }
        }
        .onChange(of: displayedMonth) { newValue in
            if !calendar.isDate(selectedDate, equalTo: newValue, toGranularity: .month) {
                selectedDate = clampedDate(in: newValue, matching: selectedDate)
            }
        }
        .onChange(of: selectedDate) { newValue in
            let newMonth = calendar.startOfMonth(for: newValue)
            if !calendar.isDate(displayedMonth, equalTo: newMonth, toGranularity: .month) {
                displayedMonth = newMonth
            }
        }
    }

    private var daysInMonth: [Date?] {
        let firstOfMonth = calendar.startOfMonth(for: displayedMonth)
        guard let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    private func moveMonth(by value: Int) {
        guard let moved = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }
        displayedMonth = calendar.startOfMonth(for: moved)
    }

    private func clampedDate(in month: Date, matching date: Date) -> Date {
        let day = min(
            calendar.component(.day, from: date),
            calendar.range(of: .day, in: .month, for: month)?.count ?? 1
        )

        return calendar.date(from: DateComponents(
            year: calendar.component(.year, from: month),
            month: calendar.component(.month, from: month),
            day: day
        )) ?? month
    }

    private func formattedMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM"
        return formatter.string(from: date)
    }
}
