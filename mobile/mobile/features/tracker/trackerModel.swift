import SwiftUI

struct CalendarDay {
    let date: Date
    let shaker: Shaker?
}

struct Shaker: Codable, Identifiable {
    let id: UUID
    let date: Date
    let completed_tasks: [String]
    let total_tasks: Int
}


