//
//  routinesSheet.swift
//  mobile
//
//  Created by Kristie on 9/12/25.
//

import SwiftUI

struct RoutinesSheet: View {
    @ObservedObject var viewModel: TaskListViewModel
    @Environment(\.dismiss) private var dismiss

    // Future work: add/edit routine flows
    @State private var targetCategoryForAdd: CategoryItem? = nil
    @State private var editingRoutine: RoutineItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            // --- Header ---
            HStack {
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle().fill(Color("Neutral-900")).frame(width: 44, height: 44)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                            .foregroundColor(Color("Neutral-400"))
                    }
                }
                Spacer()
                Text("Routines")
                    .appFont(AppFont.title2)
                    .foregroundColor(.white)
                Spacer()
                // global add (optional)
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)

            // --- List grouped by daily categories ---
            List {
                ForEach(viewModel.dailyCategoriesOnly, id: \.id) { cat in
                    Section {
                        let routines = viewModel.routinesByCategory[cat.id] ?? []
                        if routines.isEmpty {
                            emptyRow
                        } else {
                            ForEach(routines, id: \.id) { routine in
                                routineRow(routine, category: cat)
                                    .listRowSeparator(.hidden)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        // TODO: present edit routine
                                        editingRoutine = routine
                                    }
                            }
                        }
                    } header: {
                        categoryHeader(cat)
                    }
                }
            }
            .listStyle(.plain)
        }
        .onAppear {
            // make sure emoji/routines are fresh
            viewModel.refreshLatestEmojis()
            viewModel.refreshRoutines()
        }
        // todo: fullScreenCover(add/edit)
    }

    // MARK: - Header per Category
    private func categoryHeader(_ cat: CategoryItem) -> some View {
        HStack(spacing: 10) {
            Text(viewModel.latestEmoji(for: cat.id, defaultEmoji: cat.emoji))
                .appFont(AppFont.title1)
            Text(cat.name)
                .appFont(AppFont.title3)
                .foregroundColor(.white)
            Spacer()
            Button {
                // TODO: show add routine sheet for this category
                targetCategoryForAdd = cat
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("Neutral-400"))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color("Neutral-900")))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, -8)
    }

    // MARK: - Routine Row
    private func routineRow(_ r: RoutineItem, category: CategoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(r.title)
                    .appFont(AppFont.title3)
                    .foregroundStyle(.white)
                Spacer()
                statusBadge(for: r)
            }

            // period
            Text("\(formatDate(r.startDate)) ~ \(formatDate(r.endDate))")
                .appFont(AppFont.captionXS_M)
                .foregroundStyle(Color("Neutral-300"))

            // repeat summary
            Text(repeatSummary(for: r))
                .appFont(AppFont.captionXS_M)
                .foregroundStyle(Color("Neutral-300"))

            Divider()
                .frame(width: 361)
                .background(Color("Neutral-800"))
                .opacity(0.5)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty
    private var emptyRow: some View {
        Text("No routines yet")
            .appFont(AppFont.captionXS_M)
            .foregroundStyle(Color("Neutral-500"))
            .padding(.vertical, 8)
    }
}

// MARK: - Helpers (formatting)
private func formatDate(_ d: Date?) -> String {
    guard let d else { return "-" }
    let f = DateFormatter()
    f.locale = .init(identifier: "en_US_POSIX")
    f.dateFormat = "M/d/yyyy"
    return f.string(from: d)
}

private func repeatSummary(for r: RoutineItem) -> String {
    switch r.repeatType {
    case "everyday":
        return "Everyday"
    case "weekly":
        let names = (r.weeklyDays ?? [])
            .sorted()
            .map(weekdayName(_:))
        return names.joined(separator: ", ")
    case "monthly":
        let ords = (r.monthlyDays ?? [])
            .sorted()
            .map(ordinal(_:))
        return ords.joined(separator: ", ") + " of every month"
    default:
        return ""
    }
}

private func weekdayName(_ i: Int) -> String {
    // Server: 0=Sun ... 6=Sat (per our design)
    switch i {
    case 0: return "Sunday"
    case 1: return "Monday"
    case 2: return "Tuesday"
    case 3: return "Wednesday"
    case 4: return "Thursday"
    case 5: return "Friday"
    case 6: return "Saturday"
    default: return ""
    }
}

private func ordinal(_ n: Int) -> String {
    let v = n % 100
    if v >= 11 && v <= 13 { return "\(n)th" }
    switch n % 10 {
    case 1: return "\(n)st"
    case 2: return "\(n)nd"
    case 3: return "\(n)rd"
    default: return "\(n)th"
    }
}

// MARK: - Status badge
private func statusBadge(for r: RoutineItem) -> some View {
    let today = Calendar.current.startOfDay(for: Date())
    let start = Calendar.current.startOfDay(for: r.startDate)
    let end   = r.endDate.map { Calendar.current.startOfDay(for: $0) }

    let label: String
    let color: Color

    if today < start {
        label = "Be Scheduled"
        color = Color("Red-300")
    } else if let e = end, today > e {
        label = "Ended"
        color = Color("Red-300")
    } else {
        label = "In Progress"
        color = Color("Green-400")
    }

    return Text(label)
        .appFont(AppFont.labelS)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(color))
}
