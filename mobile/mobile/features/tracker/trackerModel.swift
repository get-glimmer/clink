import SwiftUI

// Supabase shaker table properties
struct Shaker: Codable, Identifiable {
    let id: UUID
    let date: String
    let completed_tasks: [String]?
    let total_tasks: Int
    let lid_color_start: String?
    let lid_color_end: String?
}

// Struct that records necessary information
struct ShakerRecord {
    let progress: Int
    let completedCount: Int
    let totalCount: Int
    let lidColor: LinearGradient
}

