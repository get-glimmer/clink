import SwiftUI

struct TrackerView: View {
    @StateObject private var trackerViewModel: TrackerViewModel
    @StateObject private var taskListViewModel: TaskListViewModel
    @State private var showMonthDropdown = false
    @State private var isWeeklyView = false
    @State private var activeTaskMenu: TaskListItem? = nil
    
    let calendar = Calendar.current
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
    let shakerWidth: CGFloat = 32

    init() {
        let userId = getUserId()
        let tracker = TrackerViewModel(userId: userId)
        let taskList = TaskListViewModel(userId: userId, date: todayDate())
        
        _trackerViewModel = StateObject(wrappedValue: tracker)
        _taskListViewModel = StateObject(wrappedValue: taskList)
        taskList.trackerViewModel = tracker   // Pass tracker to taskListViewModel
    }
    
    private func updateTaskSelectedDate(for newDate: Date) {
        if isWeeklyView {
            // Stay on the same weekday, but in the new week
            let weekday = calendar.component(.weekday, from: taskListViewModel.taskSelectedDate)
            if let sameWeekdayDate = calendar.date(
                byAdding: .day,
                value: weekday - calendar.component(.weekday, from: newDate),
                to: newDate
            ) {
                taskListViewModel.taskSelectedDate = sameWeekdayDate
            }
        } else {
            if calendar.isDate(newDate, equalTo: Date(), toGranularity: .month) {
                taskListViewModel.taskSelectedDate = Date()
            } else {
                taskListViewModel.taskSelectedDate = calendar.startOfMonth(for: newDate)
            }
        }
    }

    
    //  Moves the current week forward or backward and updates both the selected week and highlighted task date.
    private func moveDate(by value: Int) {
        if isWeeklyView {
            let newWeekStart = calendar.date(byAdding: .weekOfYear, value: value, to: trackerViewModel.selectedWeek)!
            trackerViewModel.selectedDate = newWeekStart
        } else {
            let newDate = calendar.date(byAdding: .month, value: value, to: trackerViewModel.selectedMonth)!
            trackerViewModel.selectedDate = newDate
        }
    }

    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack {
                // --- Month selector header ---
                HStack {
                    // Month text + chevron (toggle dropdown)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showMonthDropdown.toggle()
                        }
                    }) {
                        HStack(spacing: 10) {
                            Text(formattedMonthYear(trackerViewModel.selectedMonth))
                                .appFont(AppFont.title3)
                                .foregroundColor(Color("White"))

                            Image(systemName: showMonthDropdown ? "chevron.up" : "chevron.down")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 9, height: 9)
                                .foregroundColor(Color("White"))
                        }
                    }
                    .padding(.leading, 23)

                    Spacer()

                    // Prev/Next month
                    Button(action: { moveDate(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color("Neutral-400"))
                    }
                    .padding(.trailing, 16)
                    
                    Button(action: { moveDate(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color("Neutral-400"))
                    }
                    .padding(.trailing, 16)

                    // Monthly/Weekly toggle
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color("Neutral-900"))
                            .frame(width: 47, height: 30)

                        Button(action: {
                            isWeeklyView.toggle()
                            trackerViewModel.selectedDate = taskListViewModel.taskSelectedDate
                        }) {
                            Text(isWeeklyView ? "W" : "M")
                                .appFont(AppFont.labelM)
                                .foregroundColor(Color("White"))
                        }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 25)
                .onChange(of: trackerViewModel.selectedDate) {
                    updateTaskSelectedDate(for: trackerViewModel.selectedDate)
                }

                // --- Calendar grid (unchanged) ---
                LazyVGrid(columns: columns, spacing: 12) {
                    // Weekday labels
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day.uppercased())
                            .appFont(AppFont.captionXS)
                            .foregroundColor(Color("Neutral-50"))
                            .frame(maxWidth: .infinity)
                    }
                    
                    let dates = isWeeklyView ? trackerViewModel.daysInWeek : trackerViewModel.daysInMonth
                    
                    ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                        if let date = date {
                            Button(action: {
                                taskListViewModel.taskSelectedDate = date
                            }) {
                                VStack {
                                    ShakerBarView(
                                        shakerRecord: trackerViewModel.shakersRecord[formattedDate(date)]
                                    )
                                    ZStack {
                                        if calendar.isDate(date, inSameDayAs: taskListViewModel.taskSelectedDate) {
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
                        } else {
                            Color.clear.frame(height: 1)
                        }
                    }
                }
                .padding(.top, 23)
                .padding(.horizontal, 16)
                .task(id: trackerViewModel.selectedDate) {
                    try? await trackerViewModel.fetchShakers()
                }
                // when token flag is refreshed (ex. duedate changed)
                .task(id: trackerViewModel.refreshToken) {
                    try? await trackerViewModel.fetchShakers()
                }


                // --- Task list ---
                // TaskListView manages its own ScrollView (and a GeometryReader
                // inside it). Wrapping it in another ScrollView gives that
                // GeometryReader an unbounded height, collapsing the whole list
                // to zero height. Mount it directly so it fills the remaining
                // space with a bounded height.
                TaskListView(taskSelectedDate: $taskListViewModel.taskSelectedDate, viewModel: taskListViewModel, activeTask: $activeTaskMenu)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        AnalyticsService.shared.trackScreen("Home")
                        taskListViewModel.fetchCategoriesAndTasks()
                    }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .zIndex(0) // base content at bottom layer

            if showMonthDropdown {
                MonthYearDropdown(anchorMonth: $trackerViewModel.selectedDate)
                    .frame(width:240)
                    .padding(.leading, 16)
                    .padding(.top, 56)
                    .opacity(showMonthDropdown ? 1 : 0)
                    .allowsHitTesting(showMonthDropdown)
                    .zIndex(10)
            }
            
        }
        .overlay {
            if let task = activeTaskMenu {
                TaskMenuOverlay(
                    task: task,
                    viewModel: taskListViewModel,
                    onClose: { activeTaskMenu = nil }
                )
                .transition(.identity)
                .zIndex(2000)
            }
        }
        .background(.neutral1000)
        .navBarHidden(activeTaskMenu != nil)
    }
}

// Date to String in "yyyy.MM" format
func formattedMonthYear(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.MM"
    return formatter.string(from: date)
}

// preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TrackerView()
    }
}
