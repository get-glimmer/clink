import SwiftUI

struct FriendTrackerView: View {
    let friendUserId: String
    let friendName: String
    
    @StateObject private var trackerViewModel: TrackerViewModel
    @State private var showMonthPicker = false
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
    
    init(friendUserId: String, friendName: String) {
        self.friendUserId = friendUserId
        self.friendName = friendName
        let tracker = TrackerViewModel(userId: friendUserId)
        _trackerViewModel = StateObject(wrappedValue: tracker)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month selector row
            HStack {
                Button(action: { showMonthPicker = true }) {
                    HStack(spacing: 8) {
                        Text(formattedMonthYear(trackerViewModel.selectedMonth))
                            .appFont(AppFont.title3)
                            .foregroundColor(Color("White"))
                        Image(systemName: "chevron.down")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 9, height: 9)
                            .foregroundColor(Color("White"))
                    }
                }
                .sheet(isPresented: $showMonthPicker) {
                    MonthYearPicker(
                        selectedDate: $trackerViewModel.selectedDate,
                        isPresented: $showMonthPicker
                    )
                }
                
                Spacer()
                
                HStack(spacing: 27) {
                    Button(action: { moveMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color("Neutral-400"))
                    }
                    Button(action: { moveMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color("Neutral-400"))
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
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
                            // Handle date selection if needed
                        }) {
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color("Neutral-900"))
                                        .frame(width: 32, height: 30)
                                    ShakerBarView(
                                        shakerRecord: trackerViewModel.shakersRecord[formattedDate(date)]
                                    )
                                }
                                ZStack {
                                    Text("\(calendar.component(.day, from: date))")
                                        .appFont(AppFont.captionXS_M)
                                        .foregroundColor(Color("Neutral-400"))
                                }
                            }
                        }
                        .frame(width: 44, height: 72)
                    } else {
                        Color.clear.frame(height: 1)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 15)
            .task(id: trackerViewModel.selectedDate) {
                try? await trackerViewModel.fetchShakers()
            }
        }
    }
    
    private func moveMonth(by value: Int) {
        let newDate = calendar.date(byAdding: .month, value: value, to: trackerViewModel.selectedMonth)!
        trackerViewModel.selectedDate = newDate
    }
}