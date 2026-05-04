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
    let emoji_rule: String?
    let preset_emojis: [String]?
}

struct ChallengeTaskRecord: Decodable {
    let task_id: UUID
    let task_title: String?
    let sortorder: Int?
}

// Read model for challenge_invites rows; includes status to display invite lifecycle.
struct ChallengeInviteRecord: Decodable {
    let id: UUID
    let invitee_user_id: UUID?
    let status: String
}

// UI-ready model for a challenge invite with resolved profile data.
struct PendingInviteInfo: Identifiable {
    let id: UUID        // invite record id
    let userId: UUID?
    let name: String?
    let avatarUrl: String?
    let status: String  // raw value from challenge_invites.status (e.g. "pending", "declined")
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
    let preset_emojis: [String]?
}
