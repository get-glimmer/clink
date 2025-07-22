import SwiftUI

struct TrackerView: View {
    @StateObject private var trackerViewModel = TrackerViewModel()
    @StateObject private var viewModel: TaskListViewModel
    @State private var showMonthPicker = false
    @State private var isWeeklyView = false
    
    let calendar = Calendar.current
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
    
    
    
    init() {
        let userId = getUserId()
        _viewModel = StateObject(wrappedValue: TaskListViewModel(userId: userId))
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
                
                // days of weekly/monthly view
                ForEach(isWeeklyView ? trackerViewModel.daysInWeek : trackerViewModel.daysInMonth, id: \.self) { date in
                    if let date = date {
                        VStack {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.body)
                            
                            if let progress = trackerViewModel.shakersRecord[trackerViewModel.formattedDate(date)] {
                                Text(progress)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            } else {
                                Spacer().frame(height: 16)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Empty grid cell for alignment (only in monthly view)
                        Color.clear.frame(height: 40)
                    }
                }
            }
            .padding()
            .task {
                try? await trackerViewModel.fetchShakers()
            }
            TaskListView(viewModel: viewModel)
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
