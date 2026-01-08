import Foundation
import Supabase
import SwiftUI

extension Calendar {
    // extended property to get the first date of the month from the given Date
    func startOfMonth(for date: Date) -> Date {
        self.date(from: self.dateComponents([.year, .month], from: date))!
    }
    
    // extended property to get the first date of the week from the given Date
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)!
    }
    
    
    func generateMonthlyDates(for currentMonth:Date) -> [Date?] {
        let calendar = Calendar.current
        
        // unwraps an array of days ex) [1...31]
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }

        let firstOfMonth = calendar.startOfMonth(for: currentMonth)
        
        // gets day of the first date and calculates empty day slots before the first date
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        return days
    }
}

@MainActor
class TrackerViewModel: ObservableObject {
    @Published var isLoadingShakers = false
    @Published var isErrorLoadingShakers : String? = nil
    @Published var isSupabaseConnected: Bool = false
    // dictionary of shaker's [date : progress]
    @Published var shakersRecord: [String: ShakerRecord] = [:]
    // token flag that lets trackerView to know when to refresh (ex. when due date is changed)
    @Published var refreshToken = UUID()
    
    private let client = SupabaseClientManager.shared.client
    private let userId: String?
    
    init(userId: String?) {
        self.userId = userId
    }

    // 기준점이 되는 Date (IMPORTANT!!!)
    @Published var selectedDate: Date = Date()
    
    // gets updated according to selectedDate
    var selectedMonth: Date {
        Calendar.current.startOfMonth(for: selectedDate)
    }
    var selectedWeek: Date {
        Calendar.current.startOfWeek(for: selectedDate)
    }
    
    // array of Dates of the current week and month
    var daysInMonth: [Date?] {
        Calendar.current.generateMonthlyDates(for: selectedMonth)
    }
    var daysInWeek: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: selectedWeek) }
    }
    
    // refresh token to let trackerView know that it needs to update the calendar grid
    func requestShakerRefresh() {
        refreshToken = UUID()
    }
    
    // fetches shakers and saves shaker's date and progress percentage in dict
    func fetchShakers() async throws {
        guard let client = self.client else {
            self.isSupabaseConnected = false
            return
        }
        self.isSupabaseConnected = true
        
        do {
            let fetchedShakers: [Shaker] = try await client
                .from("shaker")
                .select()
                .eq("userid", value: userId)
                .execute()
                .value
            
            var record: [String: ShakerRecord] = [:]
            
            for shaker in fetchedShakers {
                let shakerDate = shaker.date
                let completedCount = shaker.completed_tasks?.count ?? 0
                let totalCount = shaker.total_tasks

                // shaker progress
                let shakerProgress: Int
                if totalCount > 0 {
                    shakerProgress = completedCount * 100 / totalCount
                } else {
                    shakerProgress = 0
                }
                
                // lid color
                let c0 = Color(hex: shaker.lid_color_start) ?? .clear
                let c1 = Color(hex: shaker.lid_color_end) ?? .clear
                
                let lidColor = LinearGradient(colors: [c0, c1],
                                              startPoint: .leading,
                                              endPoint:   .trailing)

                record[shakerDate] = ShakerRecord(
                    progress: shakerProgress,
                    completedCount: completedCount,
                    totalCount: totalCount,
                    lidColor: lidColor
                )
            }
            
            self.shakersRecord = record
            self.isErrorLoadingShakers = nil
            
        } catch {
            self.isErrorLoadingShakers = error.localizedDescription
            isSupabaseConnected = false
        }
        isLoadingShakers = false
    }
}
