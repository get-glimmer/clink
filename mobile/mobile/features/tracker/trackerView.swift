import SwiftUI

struct TrackerView: View {
    @StateObject private var trackerViewModel = TrackerViewModel()
    @StateObject private var taskListViewModel: TaskListViewModel
    @State private var showMonthPicker = false
    @State private var isWeeklyView = false
    
    let calendar = Calendar.current
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
    let shakerSize: CGFloat = 36    // global variable for shaker on a tracker
    
    // when a certain date is clicked, it applies to taskListView
    @State private var taskSelectedDate: Date = Date()

    init() {
        let userId = getUserId()
        _taskListViewModel = StateObject(wrappedValue: TaskListViewModel(userId: userId))
    }
    
    var body: some View {
        VStack {
            Spacer().frame(height: 30)
            
            // Month Selector button
            HStack {
                Button(action: {
                    showMonthPicker = true
                }) {
                    HStack(spacing: 4) {
                        Text(formattedMonthYear(trackerViewModel.selectedMonth))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Image(systemName: "chevron.down")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                    }
                }
                .sheet(isPresented: $showMonthPicker) {
                    MonthYearPicker(
                        selectedDate: $trackerViewModel.selectedDate,
                        isPresented: $showMonthPicker
                    )
                }
                
                Spacer()
                
                if isWeeklyView {
                    HStack(spacing: 16) {
                        Button(action: {
                            trackerViewModel.selectedDate = Calendar.current.date(
                                byAdding: .weekOfYear,
                                value: -1,
                                to: trackerViewModel.selectedWeek
                            )!

                        }) {
                            Image(systemName: "chevron.left")
                        }

                
                        Button(action: {
                            trackerViewModel.selectedDate = Calendar.current.date(
                                byAdding: .weekOfYear,
                                value: 1,
                                to: trackerViewModel.selectedWeek
                            )!

                        }) {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding(.bottom, 4)
                }
                
                
                Button(action: {
                    isWeeklyView.toggle()
                }) {
                    Text(isWeeklyView ? "Weekly" : "Monthly")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 10) {
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
                                if let progress = trackerViewModel.shakersRecord[trackerViewModel.formattedDate(date)] {
                                    let percentage = CGFloat(progress) / 100.0
                                    
                                    // shaker on tracker
                                    ZStack(alignment: .bottom) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: shakerSize, height: shakerSize)
                                        
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.blue)
                                            .frame(width: shakerSize, height: shakerSize * percentage)
                                    }
                                    .frame(height: shakerSize)
                                } else {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: shakerSize, height: shakerSize)
                                }

                                // dates
                                ZStack {
                                    if Calendar.current.isDate(date, inSameDayAs: taskListViewModel.taskSelectedDate) {
                                        Circle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: 20, height: 20)
                                    }
                                    
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.body)
                                        .foregroundColor(.black)
                                }
                                .frame(width: 36, height: 10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .frame(width: 44, height: 70)
                    } else {
                        Color.clear.frame(height: 1)
                    }
                }
            }
            .padding()
            .task {
                try? await trackerViewModel.fetchShakers()
            }
            TaskListView(taskSelectedDate: $taskSelectedDate, viewModel: taskListViewModel)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// helper function to format Date to String
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
