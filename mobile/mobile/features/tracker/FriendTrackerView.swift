import SwiftUI

struct FriendTrackerView: View {
    let friendUserId: String
    let friendName: String
    
    @StateObject private var trackerViewModel: TrackerViewModel
    @StateObject private var taskListViewModel: TaskListViewModel
    @StateObject private var communityViewModel = CommunityViewModel()
    @State private var isFavorite: Bool = false
    @State private var showMonthPicker = false
    @Environment(\.dismiss) private var dismiss
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
    private let shakerWidth: CGFloat = 32
    
    init(friendUserId: String, friendName: String) {
        self.friendUserId = friendUserId
        self.friendName = friendName
        let tracker = TrackerViewModel(userId: friendUserId)
        _trackerViewModel = StateObject(wrappedValue: tracker)
        let taskList = TaskListViewModel(userId: friendUserId, date: todayDate())
        taskList.trackerViewModel = tracker
        _taskListViewModel = StateObject(wrappedValue: taskList)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Centered title
                Text(friendName)
                    .appFont(AppFont.title2)
                    .foregroundColor(Color("White"))
                    .frame(maxWidth: .infinity, alignment: .center)

                // Leading/trailing controls
                HStack {
                    Button(action: { dismiss() }) {
                        Image("left_arrow")
                            .resizable()
                            .renderingMode(.original)
                            .frame(width:24, height: 24)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle().fill(AppColors.neutral900)
                            )
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        // Jar icon – tap to return to friend jar
                        Button(action: { dismiss() }) {
                            Image("jar_icon")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(AppColors.neutral400)
                                .frame(width: 24, height: 24)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle().fill(AppColors.neutral900)
                                )
                        }
                        Button(action: {
                            isFavorite.toggle()
                            if isFavorite {
                                communityViewModel.addFriendToFavorites(named: friendName)
                            } else {
                                communityViewModel.removeFriendFromFavorites(named: friendName)
                            }
                        }) {
                            Group {
                                if isFavorite {
                                    Image("star_on")
                                        .resizable()
                                        .renderingMode(.original)
                                } else {
                                    Image("star")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(AppColors.neutral400)
                                }
                            }
                            .frame(width: 24, height: 24)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle().fill(AppColors.neutral900)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16) // extra space between header and content
            
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
                            taskListViewModel.taskSelectedDate = date
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
                                    if calendar.isDate(date, inSameDayAs: taskListViewModel.taskSelectedDate) {
                                        Capsule()
                                            .fill(Color("Green-300"))
                                            .frame(width: 28, height: 16)
                                        Text("\(calendar.component(.day, from: date))")
                                            .appFont(AppFont.captionXS_M)
                                            .foregroundColor(Color.black)
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
            .padding(.vertical, 12)
            .padding(.horizontal, 15)
            .task(id: trackerViewModel.selectedDate) {
                try? await trackerViewModel.fetchShakers()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // --- daily section ---
                    HStack {
                        Text("Daily Task")
                            .font(.headline)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 4)

                    ForEach(taskListViewModel.categoriesWithTasks.filter { $0.category.type == .daily }) { item in
                        TaskCategoryCard(
                            categoryWithTasks: item,
                            backgroundColor: Color("Neutral-900"),
                            readOnly: true
                        ) {
                            EmptyView()
                        }
                        .padding(.horizontal)
                    }

                    // --- archived section ---
                    HStack {
                        Text("Archived Task")
                            .font(.headline)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 4)

                    ForEach(taskListViewModel.categoriesWithTasks.filter { $0.category.type == .archived }) { item in
                        TaskCategoryCard(
                            categoryWithTasks: item,
                            backgroundColor: Color("Neutral-900"),
                            readOnly: true
                        ) {
                            EmptyView()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 32)
            }
            .onAppear {
                taskListViewModel.fetchCategoriesAndTasks()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color("Neutral-1000").ignoresSafeArea())
    }
    
    private func moveMonth(by value: Int) {
        let newDate = calendar.date(byAdding: .month, value: value, to: trackerViewModel.selectedMonth)!
        trackerViewModel.selectedDate = newDate
    }
}


