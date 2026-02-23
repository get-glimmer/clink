import Foundation

// MARK: - Enums
// Raw values must match the Postgres public enum names exactly (shaker_type, proof_type, repeat_type).

enum ShakerType: String, CaseIterable, Codable {
    case jar    = "jar"
    case heart  = "heart"
    case star   = "star"

    var displayName: String {
        switch self {
        case .jar:   return "Jar"
        case .heart: return "Heart"
        case .star:  return "Star"
        }
    }

    var iconName: String {
        switch self {
        case .jar:   return "jar_icon"
        case .heart: return "heart"
        case .star:  return "star"
        }
    }
}

enum ProofType: String, CaseIterable, Codable {
    case photo     = "photo_upload"
    case checklist = "checklist"

    var displayName: String {
        switch self {
        case .photo:     return "Photo Upload"
        case .checklist: return "Checklist"
        }
    }

    var iconName: String {
        switch self {
        case .photo:     return "photo"
        case .checklist: return "checkboxEmpty"
        }
    }

    var usesSystemIcon: Bool {
        switch self {
        case .photo:     return true
        case .checklist: return false
        }
    }
}

enum RepeatType: String, CaseIterable, Codable {
    case everyday = "everyday"
    case weekly   = "weekly"
    case monthly  = "monthly"

    var displayName: String {
        switch self {
        case .everyday: return "Everyday"
        case .weekly:   return "Weekly"
        case .monthly:  return "Monthly"
        }
    }
}

// MARK: - DB payload types

struct ChallengeInsert: Encodable {
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
}

struct ChallengeResponse: Decodable {
    let id: UUID
}

struct ChallengeTaskInsert: Encodable {
    let challenge_id: UUID
    let task_title: String
    let sortorder: Int
}
