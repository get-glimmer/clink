import Foundation
import Supabase

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
            if let date = calendar.date(byAdding: .day, value: day - 1, to: currentMonth) {
                days.append(date)
            }
        }

        return days
    }
}

@MainActor
class TrackerViewModel: ObservableObject {
    // variables that are for state checking when fetching? might delete later
    @Published var isLoadingShakers = false
    @Published var isErrorLoadingShakers : String? = nil
    @Published var isSupabaseConnected: Bool = false
    // dictionary of shaker's [date : progress]
    @Published var shakersRecord: [String: Int] = [:]
    
    private let client = SupabaseClientManager.shared.client

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

    // helper that returns string of current month
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // fetches shakers and saves shaker's date and progress percentage in dict
    func fetchShakers() async throws {
        guard let client = self.client else {
            self.isSupabaseConnected = false
            return
        }
        self.isSupabaseConnected = true
        
        do {
            // for error printing
//            let rawData = try await client
//                .from("shaker")
//                .select()
//                .execute()
//                .data
//
//            if let json = try? JSONSerialization.jsonObject(with: rawData, options: []) {
//                print(json)
//            }

            
            let fetchedShakers: [Shaker] = try await client
                .from("shaker")
                .select()
                .execute()
                .value
            
            var record: [String: Int] = [:]
            
            for shaker in fetchedShakers {
                let shakerDate = shaker.date
                let shakerProgress = Int(Double(shaker.completed_tasks.count) / Double(shaker.total_tasks) * 100)
                
                record[shakerDate] = shakerProgress
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
