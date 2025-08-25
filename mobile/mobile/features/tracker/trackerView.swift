import SwiftUI

struct TrackerView: View {
    @StateObject private var trackerViewModel: TrackerViewModel
    @StateObject private var taskListViewModel: TaskListViewModel
    @State private var showMonthPicker = false
    @State private var isWeeklyView = false
    
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
        VStack {
            Spacer().frame(height: 10)
            
            // Month Selector button
            HStack {
                Button(action: {
                    showMonthPicker = true
                }) {
                    HStack(spacing: 10) {
                        Text(formattedMonthYear(trackerViewModel.selectedMonth))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Image(systemName: "chevron.down")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.primary)
                    }
                }
                .sheet(isPresented: $showMonthPicker) {
                    MonthYearPicker(
                        selectedDate: $trackerViewModel.selectedDate,
                        isPresented: $showMonthPicker
                    )
                }
                .onChange(of: trackerViewModel.selectedDate) {
                    updateTaskSelectedDate(for: trackerViewModel.selectedDate)
                }
                
                Spacer()
                
                // move left and right button
                HStack(spacing: 20) {
                    Button(action: {
                        moveDate(by: -1)
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }

                    Button(action: {
                        moveDate(by: 1)
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 15)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color("Neutral-900"))
                        .frame(width: 47, height: 30)
                    
                    Button(action: {
                        isWeeklyView.toggle()
                        trackerViewModel.selectedDate = taskListViewModel.taskSelectedDate
                    }) {
                        Text(isWeeklyView ? "W" : "M")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal)
            
            
            LazyVGrid(columns: columns, spacing: 0) {
                // weekday labels
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day.uppercased())
                        .font(.caption)
                        .foregroundColor(.gray)
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
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.green)
                                            .frame(width: shakerWidth, height: 17)
                                        
                                        Text("\(calendar.component(.day, from: date))")
                                            .font(.caption2)
                                            .foregroundColor(Color.black)
                                        
                                    } else {
                                        Text("\(calendar.component(.day, from: date))")
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .frame(width: shakerWidth, height: 10)
                            }
                        }
                        .frame(width: 44, height: 65)
                    } else {
                        Color.clear.frame(height: 1)
                    }
                }
            }
            .padding(10)
            .task(id: trackerViewModel.selectedDate) {
                try? await trackerViewModel.fetchShakers()
            }
            TaskListView(taskSelectedDate: $taskListViewModel.taskSelectedDate, viewModel: taskListViewModel)
                .onAppear {
                    taskListViewModel.fetchCategoriesAndTasks()
                }
        }
        .frame(maxHeight: .infinity, alignment: .top)
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
