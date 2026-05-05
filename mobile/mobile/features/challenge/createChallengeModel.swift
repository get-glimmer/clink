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
    case photoRequired = "photo_upload_required"
    case photoOptional = "photo_upload_optional"
    case checklist     = "checklist"

    var isPhoto: Bool { self == .photoRequired || self == .photoOptional }

    var displayName: String {
        switch self {
        case .photoRequired, .photoOptional: return "Photo Upload"
        case .checklist:                     return "Checklist"
        }
    }

    var iconName: String {
        switch self {
        case .photoRequired, .photoOptional: return "photo"
        case .checklist:                     return "checkboxEmpty"
        }
    }

    var usesSystemIcon: Bool {
        switch self {
        case .photoRequired, .photoOptional: return true
        case .checklist:                     return false
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

enum EmojiRule: String, CaseIterable, Codable {
    case selectedOnly = "selected_only"
    case anyEmoji     = "any_emoji"
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
    let emoji_rule: String
    let preset_emojis: [String]?
}

struct ChallengeResponse: Decodable {
    let id: UUID
}

struct ChallengeTaskInsert: Encodable {
    let challenge_id: UUID
    let task_title: String
    let sortorder: Int
}

struct ChallengeMemberInsert: Encodable {
    let challenge_id: UUID
    let user_id: UUID
    let role: String
    let member_emoji: String?
}

// Payload for inserting a pending invite into challenge_invites.
struct ChallengeInviteInsert: Encodable {
    let challenge_id: UUID
    let inviter_user_id: UUID
    let invitee_user_id: UUID
    let message: String?
}
