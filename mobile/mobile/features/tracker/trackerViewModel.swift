import Foundation
import Supabase

extension Calendar {
    // extended property to get the first day of the month from the given Date
    func startOfMonth(for date: Date) -> Date {
        self.date(from: self.dateComponents([.year, .month], from: date))!
    }
    
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)!
    }
}

@MainActor
class TrackerViewModel: ObservableObject {
    // variables that are for state checking when fetching? might delete later
    @Published var isLoadingShakers = false
    @Published var isErrorLoadingShakers : String? = nil
    @Published var isSupabaseConnected: Bool = false
    // dictionary of shaker's [date : progress]
    @Published var shakersRecord: [String: String] = [:]
    @Published var currentMonth: Date = Calendar.current.startOfMonth(for: Date())
    @Published var selectedWeekStartDate: Date = Calendar.current.startOfWeek(for: Date())

    var daysThisWeek: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: selectedWeekStartDate)
        }
    }
    
    private let client = SupabaseClientManager.shared.client
    
    // array of Dates of the current month
    var days: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: currentMonth)
        
        // unwraps an array of days ex) [1...31]
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        // gets day of the first date
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        // calculates empty day slots before the first date
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        return days
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
            let rawData = try await client
                .from("shaker")
                .select()
                .execute()
                .data

            if let json = try? JSONSerialization.jsonObject(with: rawData, options: []) {
                print(json)
            }

            
            let fetchedShakers: [Shaker] = try await client
                .from("shaker")
                .select()
                .execute()
                .value
            
            var record: [String: String] = [:]
            
            for shaker in fetchedShakers {
                let shakerDate = shaker.date
                let shakerProgress = String(format: "%.0f%%", Double(shaker.completed_tasks.count) / Double(shaker.total_tasks) * 100)
                
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
