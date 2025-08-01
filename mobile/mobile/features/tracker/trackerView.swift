import SwiftUI

struct TrackerView: View {
    @StateObject private var trackerViewModel: TrackerViewModel
    @StateObject private var taskListViewModel: TaskListViewModel
    @State private var showMonthPicker = false
    @State private var isWeeklyView = false
    
    let calendar = Calendar.current
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
    let shakerSize: CGFloat = 36    // global variable for shaker on a tracker

    init() {
        let userId = getUserId()
        
        let tracker = TrackerViewModel()
        _trackerViewModel = StateObject(wrappedValue: tracker)
        
        let taskList = TaskListViewModel(userId: userId)
        _taskListViewModel = StateObject(wrappedValue: taskList)
        
        taskList.trackerViewModel = tracker   // Pass tracker to taskListViewModel
    }
    
    //  Moves the current week forward or backward and updates both the selected week and highlighted task date.
    private func moveDate(by value: Int) {
        if isWeeklyView {
            let newWeekStart = calendar.date(byAdding: .weekOfYear, value: value, to: trackerViewModel.selectedWeek)!

            trackerViewModel.selectedDate = newWeekStart

            let weekday = calendar.component(.weekday, from: taskListViewModel.taskSelectedDate)

            if let sameWeekdayDate = calendar.date(
                byAdding: .day,
                value: weekday - calendar.component(.weekday, from: newWeekStart),
                to: newWeekStart
            ) {
                taskListViewModel.taskSelectedDate = sameWeekdayDate
            }
        } else {
            let newDate = calendar.date(byAdding: .month, value: value, to: trackerViewModel.selectedMonth)!
            trackerViewModel.selectedDate = newDate
            taskListViewModel.taskSelectedDate = calendar.date(from: calendar.dateComponents([.year, .month], from: newDate))!

            if calendar.isDate(newDate, equalTo: Date(), toGranularity: .month) {
                taskListViewModel.taskSelectedDate = Date()
            }
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
                
                Button(action: {
                    isWeeklyView.toggle()
                    trackerViewModel.selectedDate = taskListViewModel.taskSelectedDate
                }) {
                    Text(isWeeklyView ? "W" : "M")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            
            
            LazyVGrid(columns: columns, spacing: 0) {
                // weekday labels
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
                
                
                let dates = isWeeklyView ? trackerViewModel.daysInWeek : trackerViewModel.daysInMonth
                
                ForEach(dates.indices, id: \.self) { index in
                    if let date = dates[index] {
                        Button(action: {
                            taskListViewModel.taskSelectedDate = date   // when a date is selected
                        }) {
                            VStack {
                                ShakerBarView(
                                    progress: trackerViewModel.shakersRecord[trackerViewModel.formattedDate(date)],
                                    size: shakerSize
                                )
                                
                                // dates
                                ZStack {
                                    if Calendar.current.isDate(date, inSameDayAs: taskListViewModel.taskSelectedDate) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.green)
                                            .frame(width: shakerSize, height: 20)
                                    }
                                    
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: shakerSize, height: 10)
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
