import SwiftUI

struct FriendTrackerView: View {
    let friendUserId: String
    let friendName: String
    @ObservedObject var friendTaskViewModel: TaskListViewModel
    
    @StateObject private var trackerViewModel: TrackerViewModel
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
    
    init(friendUserId: String, friendName: String, friendTaskViewModel: TaskListViewModel) {
        self.friendUserId = friendUserId
        self.friendName = friendName
        self.friendTaskViewModel = friendTaskViewModel
        let tracker = TrackerViewModel(userId: friendUserId)
        // Keep the friend's calendar month anchored to whatever day
        // the bottom sheet/task VM is currently showing.
        tracker.selectedDate = friendTaskViewModel.taskSelectedDate
        _trackerViewModel = StateObject(wrappedValue: tracker)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day.uppercased())
                        .appFont(AppFont.captionXS)
                        .foregroundColor(Color("Neutral-50"))
                        .frame(maxWidth: .infinity)
                }
                
                let dates = trackerViewModel.daysInMonth
                ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        Button(action: {
                            // Mirror main TrackerView behavior:
                            // update the friend's task-selected date (drives the bottom sheet)
                            // and keep the internal tracker selection in sync so shakers refresh.
                            friendTaskViewModel.taskSelectedDate = date
                            trackerViewModel.selectedDate = date
                        }) {
                            VStack(spacing: 6) {
                                // Match the main TrackerView calendar style:
                                // show only the shaker bar without an extra dark container.
                                ShakerBarView(
                                    shakerRecord: trackerViewModel.shakersRecord[formattedDate(date)]
                                )
                                .frame(width: 32, height: 30)

                                ZStack {
                                    if calendar.isDate(date, inSameDayAs: friendTaskViewModel.taskSelectedDate) {
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
                        .frame(width: 44, height: 72)
                    } else {
                        Color.clear.frame(height: 1)
                    }
                }
            }
            .padding(.vertical, 35)
            .padding(.horizontal, 18)
            // Keep shaker bars in sync with the selected day/month.
            .task(id: trackerViewModel.selectedDate) {
                try? await trackerViewModel.fetchShakers()
            }
        }
        // If something else (e.g., ShakerView) moves the friend's selected day,
        // mirror that change into this calendar so highlight & shakers stay aligned.
        .onChange(of: friendTaskViewModel.taskSelectedDate) { newDate in
            trackerViewModel.selectedDate = newDate
        }
    }
}