import Foundation

// MARK: - DB payload types

struct ChallengeRecord: Decodable {
    let id: UUID
    let title: String
    let description: String?
    let shaker_type: String
    let proof_type: String
    let start_date: String?
    let end_date: String?
    let repeat_type: String
    let weekly_days: [Int]?
    let monthly_days: [Int]?
}

struct ChallengeTaskRecord: Decodable {
    let task_id: UUID
    let task_title: String?
    let sortorder: Int?
}

struct ChallengeUpdate: Encodable {
    let title: String
    let description: String?
    let shaker_type: String
    let proof_type: String
    let start_date: String?
    let end_date: String?
    let repeat_type: String
    let weekly_days: [Int]?
    let monthly_days: [Int]?
}
