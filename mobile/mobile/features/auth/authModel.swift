import Foundation

/**
 * Represents a user's profile.
 * Conforms to Codable for JSON serialization, Identifiable for use in SwiftUI lists, and Equatable for comparison.
 */
struct Profile: Codable, Identifiable, Equatable {
    // MARK: - Properties

    /// The unique identifier for the profile.
    var id: UUID

    /// The user's full name.
    var name: String

    /// The URL for the user's avatar image.
    var avatar_url: String?

    /// A short biography of the user.
    var bio: String?

    /// The user's email address.
    var email: String?

    /// The user's phone number.
    var phoneNumber: String?

    /// A local-only property to store the number of friends, not stored in the database.
    var friendsCount: Int?
    
    var username: String?

    // MARK: - CodingKeys

    /// Specifies the keys to be used for encoding and decoding, excluding `friendsCount`.
    private enum CodingKeys: String, CodingKey {
        case id, name, username, avatar_url, bio, email, phoneNumber
    }
}

/**
 * A data structure for creating or updating a user's profile.
 * Conforms to Encodable to be sent as JSON in API requests.
 */
struct ProfileInput: Encodable {
    // MARK: - Properties

    /// The unique identifier of the user.
    let id: String

    /// The user's full name.
    let name: String?

    /// The user's chosen username.
    let username: String?

    /// The user's email address.
    let email: String?

    /// The user's phone number.
    let phoneNumber: String?

    /// The URL for the user's avatar image.
    let avatar_url: String?

    /// The user's date of birth in ISO 8601 format.
    let dob: String?
}
