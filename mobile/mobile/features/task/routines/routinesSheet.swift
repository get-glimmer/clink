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
                    Image("dismissButton")
                }
                Spacer()
                Text("Routines")
                    .appFont(AppFont.title2)
                    .foregroundColor(.white)
                Spacer()
                // global add (optional)
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, -10) //32-42

            // --- routine list grouped by daily categories ---
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(viewModel.dailyCategoriesOnly, id: \.id) { cat in
                        categoryHeader(cat)

                        // Routines of the category
                        let routines = viewModel.routinesByCategory[cat.id] ?? []
                        if !routines.isEmpty {
                            ForEach(routines, id: \.id) { routine in
                                routineRow(routine, category: cat)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingRoutine = routine
                                    }
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            viewModel.refreshLatestEmojis()
            viewModel.refreshRoutines()
        }
        .fullScreenCover(item: $targetCategoryForAdd) { cat in
            AddRoutineSheet(category: cat, viewModel: viewModel)
        }
        .fullScreenCover(item: $editingRoutine) { r in
            EditRoutineSheet(routine: r, viewModel: viewModel)
        }
    }

    // MARK: - Header per Category
    private func categoryHeader(_ cat: CategoryItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(viewModel.latestEmoji(for: cat.id, defaultEmoji: cat.emoji))
                    .font(.system(size: 27))
                Text(cat.name)
                    .appFont(AppFont.title3)
                    .foregroundColor(.white)
                    .padding(.leading, 1.42)
                Spacer()
                Button {
                    targetCategoryForAdd = cat
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(Color("Neutral-400"))
                }
                .buttonStyle(.plain)
                // add routine
            }
            .padding(.horizontal, 20)

            Divider()
                .frame(width: 361)
                .background(Color("Neutral-800"))
                .opacity(0.5)
                .padding(.top, 16)
        }
        .padding(.top, 42)
    }

    // MARK: - Routine Row
    private func routineRow(_ r: RoutineItem, category: CategoryItem) -> some View {
        VStack{
            VStack(alignment: .leading, spacing: 6) {
                // task title
                Text(r.title)
                    .appFont(AppFont.labelM)
                    .foregroundStyle(.white)
                
                // period + status badge
                HStack(alignment: .center) {
                    Text("\(formatDate(r.startDate)) - \(formatDate(r.endDate))")
                        .appFont(AppFont.captionXS_M)
                        .foregroundStyle(Color("Neutral-400"))
                    Spacer()
                    statusBadge(for: r)
                }
                
                // repeat summary
                Text(repeatSummary(for: r))
                    .appFont(AppFont.captionXS_M)
                    .foregroundStyle(Color("Neutral-400"))
            }
            .padding(.horizontal, 6)
            .padding(.top, 15)
            .padding(.bottom, 9)
            
            Divider()
                .frame(width: 361)
                .background(Color("Neutral-800"))
                .opacity(0.5)
        }
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
        color = Color("Green-300")
    }

    return Text(label)
        .appFont(AppFont.labelS)
        .foregroundColor(Color("Neutral-1000"))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(color))
}
