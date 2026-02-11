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
    let repeat_rule: RepeatRule
    let created_at: String?
    let updated_at: String?
}

struct RepeatRule: Codable {
    let type: String?          // "daily", "weekly", "monthly"
    let days_per_week: Int?    // e.g. 3
    let days_per_month: [Int]? // e.g. [1, 15]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.days_per_week = try container.decodeIfPresent(Int.self, forKey: .days_per_week)
        self.days_per_month = try container.decodeIfPresent([Int].self, forKey: .days_per_month)
    }

    /// Human-readable frequency string for the UI
    var frequencyText: String {
        switch type {
        case "daily":
            return "Everyday"
        case "weekly":
            if let days = days_per_week {
                return "\(days) days a week"
            }
            return "Weekly"
        case "monthly":
            if let days = days_per_month {
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
