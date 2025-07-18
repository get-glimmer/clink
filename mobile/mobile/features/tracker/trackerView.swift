import SwiftUI

struct TrackerView: View {
    @StateObject private var trackerViewModel = TrackerViewModel()
    @State private var showMonthPicker = false
    
    let calendar = Calendar.current
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
    
    var body: some View {
        VStack {
            // Month Selector button
            HStack {
                Spacer()
                Button(action: {
                    showMonthPicker = true
                }) {
                    HStack(spacing: 4) {
                        Text(formattedMonthYear(trackerViewModel.currentMonth))
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
                        selectedDate: $trackerViewModel.currentMonth,
                        isPresented: $showMonthPicker
                    )
                }
                Spacer()
            }
            .padding(.bottom, 8)
            
            LazyVGrid(columns: columns, spacing: 10) {
                // weekday labels
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
                
                // days
                ForEach(trackerViewModel.days, id: \.self) { date in
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
                        // Empty grid cell for alignment
                        Color.clear.frame(height: 40)
                    }
                }
            }
            .padding()
        }
        .task {
            try? await trackerViewModel.fetchShakers()
        }
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
