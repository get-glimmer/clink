import SwiftUI

// Supabase shaker table properties
struct Shaker: Codable, Identifiable {
    let id: UUID
    let date: String
    let completed_tasks: [String]?
    let total_tasks: Int
}

struct ShakerRecord {
    let progress: Int
    let completedCount: Int
    let totalCount: Int
}

