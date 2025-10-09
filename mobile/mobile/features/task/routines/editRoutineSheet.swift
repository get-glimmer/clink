//
//  editRoutineSheet.swift
//  mobile
//
//  Created by Kristie on 9/21/25.
//

import SwiftUI

struct EditRoutineSheet: View {
    // Input
    let routine: RoutineItem
    @ObservedObject var viewModel: TaskListViewModel

    // UI States
    @Environment(\.dismiss) private var dismiss
    @State private var titleText: String = ""

    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil

    @State private var showFromPicker = false
    @State private var showToPicker   = false

    @State private var multiDates = Set<DateComponents>()  // for monthly

    // Calendar tuning (same as Add)
    private let kMonthPadH: CGFloat = 10
    private let kMonthPadV: CGFloat = 10
    private let kMonthScale: CGFloat = 0.92

    enum RepeatType: String, CaseIterable, Identifiable {
        case everyday, weekly, monthly
        var id: String { rawValue }
        var display: String {
            switch self {
            case .everyday: return "Everyday"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            }
        }
        var dbValue: String? {
            switch self {
            default: return rawValue
            }
        }
    }
    @State private var repeatType: RepeatType = .everyday
    @State private var weeklyDays: Set<Int> = []     // 0..6
    @State private var monthCursor: Date = Date()
    @State private var monthlyDays: Set<Int> = []    // 1..31

    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    init(routine: RoutineItem, viewModel: TaskListViewModel) {
        self.routine = routine
        self._viewModel = ObservedObject(initialValue: viewModel)
        // seed states in init’s on-appear alternative (SwiftUI updates environment later)
        // We'll actually seed in .onAppear to ensure View is ready.
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    titleSection
                    durationSection
                    repeatSection

                    if let err = errorMessage, !err.isEmpty {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 120)
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
                    Text("Edit Routine")
                        .appFont(AppFont.title2)
                        .foregroundColor(Color("White"))
                }
                // Delete
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await deleteRoutine() }
                    } label: {
                        Image("trashcan")
                    }
                }
            }
            .onAppear(perform: seedFromRoutine)

            .safeAreaInset(edge: .bottom) {
                Button(action: { Task { await saveRoutine() } }) {
                    Text(isSaving ? "Saving..." : "Done")
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .appFont(AppFont.title3)
                        .foregroundStyle(.black)
                        .background(isSaving ? Color("Green-300").opacity(0.5) : Color("Green-300"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isSaving || isDeleting)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Sections
    private var titleSection: some View {
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
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .appFont(AppFont.labelS)
                .foregroundColor(Color("Neutral-300"))
                .padding(.horizontal, 8)

            VStack(spacing: 0) {
                durationRow(title: "From",
                            value: startDate.map { mdY($0) } ?? "None") {
                    withAnimation {
                        showFromPicker.toggle()
                        if showFromPicker { showToPicker = false }
                    }
                }

                if showFromPicker {
                    innerDivider
                    CustomCalendar(
                        selectedDate: Binding(
                            get: { startDate ?? Date() },
                            set: { startDate = startOfDay($0) }
                        ),
                        lowerBound: nil,
                        upperBound: endDate
                    )
                }

                innerDivider

                durationRow(title: "To",
                            value: endDate.map { mdY($0) } ?? "None") {
                    withAnimation {
                        showToPicker.toggle()
                        if showToPicker { showFromPicker = false }
                    }
                }

                if showToPicker {
                    innerDivider
                    CustomCalendar(
                        selectedDate: Binding(
                            get: { endDate ?? (startDate ?? Date()) },
                            set: { endDate = startOfDay($0) }
                        ),
                        lowerBound: startDate,
                        upperBound: nil
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
            )
        }
        .padding(.horizontal, 16)
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeat")
                .appFont(AppFont.labelS)
                .foregroundColor(Color("Neutral-300"))
                .padding(.horizontal, 8)

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color("Neutral-300"))
                        Text("Repeat")
                            .appFont(AppFont.labelM)
                            .foregroundColor(Color("Neutral-300"))
                    }
                    Spacer()
                    Menu {
                        ForEach(RepeatType.allCases) { t in
                            Button(t.display) {
                                repeatType = t
                                // clear incompatible selections when switching
                                if t != .weekly { weeklyDays.removeAll() }
                                if t != .monthly { monthlyDays.removeAll(); multiDates.removeAll() }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(repeatType.display)
                                .appFont(AppFont.body1)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote)
                                .foregroundColor(Color("Neutral-300"))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                }
                .frame(height: 52)
                .padding(.horizontal, 12)

                if repeatType == .weekly {
                    innerDivider
                    weeklyChips
                }

                if repeatType == .monthly {
                    innerDivider
                    monthlyPickerInsideBox
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Parts
    private func durationRow(title: String, value: String, onTap: @escaping () -> Void) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("Neutral-300"))
                Text(title)
                    .appFont(AppFont.labelM)
                    .foregroundColor(Color("Neutral-300"))
            }
            Spacer()
            Text(value)
                .appFont(AppFont.body1)
                .foregroundColor(.white)
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(Color("Neutral-300"))
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

    private var weeklyChips: some View {
        let labels = ["SUN","MON","TUE","WED","THU","FRI","SAT"]
        return HStack(spacing: 7) {
            ForEach(0..<7, id: \.self) { i in
                let selected = weeklyDays.contains(i)
                Text(labels[i])
                    .appFont(AppFont.captionXS)
                    .foregroundStyle(selected ? Color.black : Color("Neutral-50"))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Capsule().fill(selected ? Color("Green-300") : Color("Neutral-900")))
                    .onTapGesture {
                        if selected { weeklyDays.remove(i) } else { weeklyDays.insert(i) }
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var monthlyPickerInsideBox: some View {
        if #available(iOS 16.0, *) {
            VStack(spacing: 0) {
                MultiDatePicker("", selection: $multiDates)
                    .tint(Color("Green-300"))
                    .labelsHidden()
                    .onChange(of: multiDates) { newVal in
                        monthlyDays = Set(newVal.compactMap { $0.day })
                    }
                    .onAppear {
                        if multiDates.isEmpty {
                            let base = monthCursor
                            let cal = Calendar.current
                            let y = cal.component(.year, from: base)
                            let m = cal.component(.month, from: base)
                            multiDates = Set(monthlyDays.map { DateComponents(year: y, month: m, day: $0) })
                        }
                    }
                    .scaleEffect(kMonthScale, anchor: .top)
                    .padding(.horizontal, kMonthPadH)
                    .padding(.vertical, kMonthPadV)
            }
            .padding(.bottom, -6)
        }
    }

    // MARK: - Seed from existing routine
    private func seedFromRoutine() {
        titleText = routine.title
        startDate = routine.startDate
        endDate   = routine.endDate

        switch routine.repeatType {
        case "weekly":   repeatType = .weekly
        case "monthly":  repeatType = .monthly
        default:         repeatType = .everyday
        }
        weeklyDays  = Set(routine.weeklyDays ?? [])
        monthlyDays = Set(routine.monthlyDays ?? [])
        // seed MultiDatePicker dots
        if #available(iOS 16.0, *) {
            let base = Date()
            let cal = Calendar.current
            let y = cal.component(.year, from: base)
            let m = cal.component(.month, from: base)
            multiDates = Set(monthlyDays.map { DateComponents(year: y, month: m, day: $0) })
        }
    }

    // MARK: - Actions
    private func saveRoutine() async {
        errorMessage = nil
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { errorMessage = "Please enter a title."; return }
        guard let s = startDate else { errorMessage = "Please select a start date."; return }
        if let e = endDate, e < s { errorMessage = "End date cannot be earlier than start date."; return }

        isSaving = true
        let ok = await viewModel.updateRoutine(
            routineId: routine.id,
            title: title,
            repeatType: repeatType.dbValue,
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

    private func deleteRoutine() async {
        errorMessage = nil
        isDeleting = true
        let ok = await viewModel.deleteRoutine(routineId: routine.id)
        isDeleting = false
        if ok {
            await MainActor.run {
                viewModel.refreshRoutines()
                dismiss()
            }
        } else {
            errorMessage = "Failed to delete routine."
        }
    }
}

// MARK: - small helpers
private func startOfDay(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }
private func mdY(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX"); f.dateFormat = "M/d/yyyy"
    return f.string(from: d)
}
