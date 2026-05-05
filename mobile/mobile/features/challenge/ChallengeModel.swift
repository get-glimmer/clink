import Foundation

// MARK: - Database Models (Codable, match Supabase table columns)

struct ChallengeData: Codable, Identifiable {
    let id: UUID
    let owner_user_id: UUID
    let title: String
    let description: String?
    let shaker_type: String
    let proof_type: String
    let start_date: String?
    let end_date: String?
    let repeat_type: String
    let weekly_days: [Int]?
    let monthly_days: [Int]?
    let created_at: String?
    let updated_at: String?
    let emoji_rule: String?
    let preset_emojis: [String]?

    /// Human-readable frequency string for the UI
    var frequencyText: String {
        switch repeat_type {
        case "everyday", "daily":
            return "Everyday"
        case "weekly":
            if let days = weekly_days, !days.isEmpty {
                return "\(days.count) days a week"
            }
            return "Weekly"
        case "monthly":
            if let days = monthly_days, !days.isEmpty {
                return "\(days.count) days a month"
            }
            return "Monthly"
        default:
            return "No schedule"
        }
    }
}


struct ChallengeMemberData: Codable {
    let challenge_id: UUID
    let user_id: UUID
    let role: String
    let joined_at: String?
    let left_at: String?
    let member_emoji: String?
    let favorite: Bool?
}

struct ChallengeMemberProfile: Codable {
    let challenge_id: UUID
    let user_id: UUID
    let role: String
    let left_at: String?
    let member_emoji: String?
    let profiles: ProfileData?
}

struct ProfileData: Codable {
    let id: UUID
    let name: String?
    let avatar_url: String?
}

struct ChallengeTaskData: Codable, Identifiable {
    var id: UUID { task_id }
    let task_id: UUID
    let challenge_id: UUID
    let task_title: String?
    let sortorder: Int?
}

struct ChallengeTaskCompletionData: Codable {
    let id: UUID
    let challenge_id: UUID
    let task_id: UUID?
    let user_id: UUID?
    let date: String?
    let is_completed: Bool?
}

struct ChallengeShakerData: Codable {
    let id: UUID
    let challenge_id: UUID
    let date: String
    let iscompleted: Bool
    let user_emojis: [String]
    let lid_color_start: String?
    let lid_color_end: String?
}

// MARK: - UI-Ready Model

struct ChallengeItem: Identifiable {
    let id: UUID
    let ownerUserId: UUID
    let title: String
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let frequency: String
    let shakerType: String
    let memberCount: Int
    let members: [MemberInfo]
    let taskCount: Int
    let completedTaskCount: Int

    // Shaker (from challenge_shaker table)
    let shakerIsCompleted: Bool
    let shakerUserEmojis: [String]
    let shakerLidColorStart: String?
    let shakerLidColorEnd: String?

    /// Formatted date range for the green pill, e.g. "2/1 - 2/28"
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let start = startDate.map { formatter.string(from: $0) } ?? "?"
        let end = endDate.map { formatter.string(from: $0) } ?? "?"
        return "\(start) - \(end)"
    }

    /// Days remaining until end_date, nil if no end date
    var daysLeft: Int? {
        guard let endDate = endDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: endDate))
        return max(0, components.day ?? 0)
    }

    /// Progress as a percentage (0–100) based on task completions
    var progressPercent: Int {
        guard taskCount > 0 else { return 0 }
        return Int(Double(completedTaskCount) / Double(taskCount) * 100)
    }
}

struct MemberInfo {
    let userId: UUID
    let name: String?
    let avatarUrl: String?
    let emoji: String?
    let role: String
}

// MARK: - Pending Invite DB model

struct InviteData: Decodable {
    let id: UUID
    let challenge_id: UUID
    let inviter_user_id: UUID
    let message: String?
    let status: String
}

// MARK: - UI-Ready model for a pending invitation

struct InvitedChallengeItem: Identifiable {
    let id: UUID            // invite id
    let challengeId: UUID
    let title: String
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let frequency: String
    let emojiRule: EmojiRule
    let presetEmojis: [String]
    let memberCount: Int
    let inviterName: String?
    let message: String?

    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let start = startDate.map { formatter.string(from: $0) } ?? "?"
        let end = endDate.map { formatter.string(from: $0) } ?? "?"
        return "\(start) - \(end)"
    }
}
