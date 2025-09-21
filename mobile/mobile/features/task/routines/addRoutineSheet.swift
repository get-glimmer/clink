//
//  addRoutineSheet.swift
//  mobile
//
//  Created by Kristie on 9/21/25.
//
// AddRoutineSheet.swift
// mobile
//
// Create a new routine under a given category.
// Style follows AddCategorySheet (colors, spacing, strokes).

import SwiftUI

struct AddRoutineSheet: View {
    // Input
    let category: CategoryItem
    @ObservedObject var viewModel: TaskListViewModel

    // UI States
    @Environment(\.dismiss) private var dismiss
    @State private var titleText: String = ""

    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil

    @State private var showFromPicker = false
    @State private var showToPicker   = false
    
    @State private var multiDates = Set<DateComponents>()

    // Repeat
    enum RepeatType: String, CaseIterable, Identifiable {
        case none, everyday, weekly, monthly
        var id: String { rawValue }
        var display: String {
            switch self {
            case .none: return "None"
            case .everyday: return "Everyday"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            }
        }
        var dbValue: String? {
            switch self {
            case .none: return nil
            default: return rawValue
            }
        }
    }
    @State private var repeatType: RepeatType = .none
    @State private var weeklyDays: Set<Int> = []          // 0..6 (Sun..Sat)

    // monthly picker
    @State private var monthCursor: Date = Date()         // which month to show
    @State private var monthlyDays: Set<Int> = []         // 1..31

    // Save
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // ==== Title ====
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .appFont(AppFont.labelS)
                        .foregroundColor(Color("Neutral-300"))
                        .padding(.horizontal, 8)

                    TextField("Write a title...", text: $titleText)
                        .appFont(AppFont.body1)
                        .foregroundColor(Color("White"))
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
                        )
                }
                .padding(.horizontal, 16)

                // ==== Duration ====
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration")
                        .appFont(AppFont.labelS)
                        .foregroundColor(Color("Neutral-300"))
                        .padding(.horizontal, 8)

                    VStack(spacing: 0) {
                        durationRow(icon: "calendar", title: "From",
                                    value: startDate.map { mdY($0) } ?? "None") {
                            withAnimation {
                                showFromPicker.toggle()
                                showToPicker = false
                            }
                        }
                        innerDivider
                        durationRow(icon: "calendar", title: "To",
                                    value: endDate.map { mdY($0) } ?? "None") {
                            withAnimation {
                                showToPicker.toggle()
                                showFromPicker = false
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
                    )

                    if showFromPicker {
                        calendarBox(
                            selection: Binding(
                                get: { startDate ?? Date() },
                                set: { startDate = startOfDay($0) }
                            ),
                            lower: nil, upper: endDate
                        )
                    }
                    if showToPicker {
                        calendarBox(
                            selection: Binding(
                                get: { endDate ?? (startDate ?? Date()) },
                                set: { endDate = startOfDay($0) }
                            ),
                            lower: startDate, upper: nil
                        )
                    }
                }
                .padding(.horizontal, 16)

                // ==== Repeat ====
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repeat")
                        .appFont(AppFont.labelS)
                        .foregroundColor(Color("Neutral-300"))
                        .padding(.horizontal, 8)

                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: "clock")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("White"))
                            Text("Repeat")
                                .appFont(AppFont.body1)
                                .foregroundColor(Color("White"))
                        }
                        Spacer()
                        Menu {
                            ForEach(RepeatType.allCases) { t in
                                Button(t.display) { repeatType = t }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(repeatType.display)
                                    .appFont(AppFont.body1)
                                    .foregroundColor(Color("White"))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.footnote)
                                    .foregroundColor(Color("White"))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                    }
                    .frame(height: 52)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
                    )

                    if repeatType == .weekly { weeklyChips }
                    if repeatType == .monthly { monthlyCalendar }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 12)

                if let err = errorMessage, !err.isEmpty {
                    Text(err).foregroundStyle(.red).font(.footnote)
                        .padding(.horizontal, 16)
                }

                Button(action: saveRoutine) {
                    Text(isSaving ? "Saving..." : "Done")
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .appFont(AppFont.title3)
                        .background(isSaving ? Color("Green-300").opacity(0.5) : Color("Green-300"))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isSaving)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle().fill(Color("Neutral-900")).frame(width: 44, height: 44)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14))
                                .foregroundColor(Color("Neutral-400"))
                        }
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .principal) {
                    Text("Add Routine")
                        .appFont(AppFont.title2)
                        .foregroundColor(Color("White"))
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Rows & Parts
    private func durationRow(icon: String, title: String, value: String, onTap: @escaping () -> Void) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("White"))
                Text(title)
                    .appFont(AppFont.body1)
                    .foregroundColor(Color("White"))
            }
            Spacer()
            Text(value)
                .appFont(AppFont.body1)
                .foregroundColor(Color("White"))
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(Color("White"))
        }
        .frame(height: 52)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var innerDivider: some View {
        Rectangle().fill(Color("Neutral-800"))
            .frame(height: 0.7)
            .padding(.horizontal, 12)
    }

    private func calendarBox(selection: Binding<Date>, lower: Date?, upper: Date?) -> some View {
        VStack(spacing: 12) {
            DatePicker("", selection: selection,
                       in: (lower ?? Date.distantPast)...(upper ?? Date.distantFuture),
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Color("Green-300"))
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
        )
    }

    private var weeklyChips: some View {
        let labels = ["SUN","MON","TUE","WED","THU","FRI","SAT"]
        return VStack {
            Rectangle().fill(Color("Neutral-800")).frame(height: 0.7)
                .padding(.horizontal, 4)
                .padding(.bottom, 12)
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let selected = weeklyDays.contains(i)
                    Text(labels[i])
                        .appFont(AppFont.captionXS)
                        .foregroundStyle(selected ? Color.black : Color("Neutral-300"))
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Capsule().fill(selected ? Color("Green-300") : Color("Neutral-800")))
                        .onTapGesture {
                            if selected { weeklyDays.remove(i) } else { weeklyDays.insert(i) }
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Monthly picker using system MultiDatePicker
    @ViewBuilder
    private var monthlyCalendar: some View {
        if #available(iOS 16.0, *) {
            VStack(spacing: 12) {
                Rectangle().fill(Color("Neutral-800")).frame(height: 0.7)
                    .padding(.horizontal, 4)

                // System multi-select calendar
                MultiDatePicker("", selection: $multiDates)
                    .tint(Color("Green-300"))
                    .labelsHidden()
                    .environment(\.calendar, Calendar.current)
                    .onChange(of: multiDates) { newVal in
                        // Normalize: keep only the "day" (1...31) regardless of month/year
                        let days = newVal.compactMap { $0.day }
                        monthlyDays = Set(days)
                    }
                    .onAppear {
                        // Seed selections from current monthlyDays for the currently visible month
                        // (we don’t care about month/year; they’re only to visualize initial dots)
                        if multiDates.isEmpty {
                            let base = monthCursor   // reuse your monthCursor if you have it, or Date()
                            let cal = Calendar.current
                            let y = cal.component(.year, from: base)
                            let m = cal.component(.month, from: base)
                            multiDates = Set(monthlyDays.map { day in
                                DateComponents(year: y, month: m, day: day)
                            })
                        }
                    }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
            )
        }
    }

    // MARK: - Save
    private func saveRoutine() {
        errorMessage = nil
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { errorMessage = "Please enter a title."; return }
        guard let s = startDate else { errorMessage = "Please select a start date."; return }
        if let e = endDate, e < s { errorMessage = "End date cannot be earlier than start date."; return }

        isSaving = true
        Task {
            let ok = await viewModel.addRoutine(
                categoryId: category.id,
                title: title,
                repeatType: repeatType.dbValue,              // nil or string
                startDate: s,
                endDate: endDate,
                weeklyDays: repeatType == .weekly ? Array(weeklyDays).sorted() : nil,
                monthlyDays: repeatType == .monthly ? Array(monthlyDays).sorted() : nil
            )
            isSaving = false
            if ok {
                await MainActor.run {
                    viewModel.refreshRoutines()
                    dismiss()
                }
            } else {
                errorMessage = "Failed to save routine."
            }
        }
    }
}

// MARK: - Small date helpers (same formatting used in routines list)
private func startOfDay(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }
private func mdY(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX"); f.dateFormat = "M/d/yyyy"
    return f.string(from: d)
}
private func monthTitle(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX"); f.dateFormat = "yyyy.MM"
    return f.string(from: d)
}
private func addMonths(_ d: Date, _ m: Int) -> Date {
    Calendar.current.date(byAdding: .month, value: m, to: d) ?? d
}
// Returns a 6-week grid of the month as [Int?] where nil = filler
private func monthGridNumbers(for base: Date) -> [Int?] {
    let cal = Calendar.current
    let y = cal.component(.year, from: base)
    let m = cal.component(.month, from: base)
    let first = cal.date(from: DateComponents(year: y, month: m, day: 1))!
    let days = cal.range(of: .day, in: .month, for: first)!.count
    let firstWeekday = cal.component(.weekday, from: first) // 1(Sun)..7(Sat)
    var result: [Int?] = Array(repeating: nil, count: firstWeekday - 1)
    result.append(contentsOf: (1...days).map { Optional($0) })
    while result.count % 7 != 0 { result.append(nil) }
    while result.count < 42 { result.append(nil) }
    return result
}
