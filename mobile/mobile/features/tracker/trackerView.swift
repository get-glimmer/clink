import SwiftUI

struct TrackerView: View {
    var body: some View {
        let today = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        
        let dummyShakers: [Shaker] = (0..<Int(31)).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startOfMonth) ?? today
            return Shaker(id: UUID(), date: date, completed_tasks: [], total_tasks: 0) // Or other dummy data
        }
        
        VStack {
            CalendarView(shakers: dummyShakers)
            ShakerView()
        }
    }
}
