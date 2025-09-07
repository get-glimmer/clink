import Foundation

struct Profile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var avatar_url: String?
    var bio: String?
    var email: String?
    var phoneNumber: String?

    // Local-only field (not in DB, not decoded/encoded)
    var friendsCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, avatar_url, bio, email, phoneNumber
        // exclude friendsCount
    }
}

struct ProfileInput: Encodable {
    let id: String
    let name: String?
    let username: String?
    let email: String?
    let phoneNumber: String?
    let avatar_url: String?
    let dob: String? // ISO8601 string
}
