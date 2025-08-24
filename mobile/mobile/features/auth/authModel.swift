import Foundation

struct Profile: Codable, Identifiable, Equatable {
    var id: UUID            // Local or DB ID
    var name: String
    var avatar_url: String?
//    var created_at: Date?
    var bio: String?
//    var friendsTableID: String?
    var email: String
    var friendsCount: Int?
}



