import Foundation
import Supabase

// prevents concurrency bugs and UI glitches
@MainActor
class TrackerViewModel: ObservableObject {
//    @Published var shakers = [Shaker]()
    // dictionary of shaker's [date : progress]
    @Published var shakersRecord: [String: Double] = [:]
    @Published var isLoadingShakers = false
    @Published var isErrorLoadingShakers : String? = nil
    
    var days: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!

        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // fetches 
    func fetchShakers() async throws {
        do {
            let fetchedShakers: [Shaker] = try await supabase
                .from("shaker")
                .select()
                .execute()
                .value

            var record: [String: Double] = [:]
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            for shaker in fetchedShakers {
                let shakerDate = formatter.string(from: shaker.date)
                let progress = shaker.total_tasks == 0 ? 0.0 : Double(shaker.completed_tasks.count) / Double(shaker.total_tasks)
                record[shakerDate] = progress
            }

//            self.shakers = fetchedShakers
            self.shakersRecord = record
            self.isErrorLoadingShakers = nil
        } catch {
            self.isErrorLoadingShakers = error.localizedDescription
        }
        
        isLoadingShakers = false
    }
}
