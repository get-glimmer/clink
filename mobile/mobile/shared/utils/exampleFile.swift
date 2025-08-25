import Foundation

let hardcodedUserId = "f221d19a-9da8-44eb-b14c-d4a315c23d85"
let name = "Cicero"
let avatar_url = "https://picsum.photos/200/300"

func saveUserId() {
    UserDefaults.standard.set(hardcodedUserId, forKey: "userId")
}

func getUserId() -> String? {
    let client = SupabaseClientManager.shared.client
    // Get the current session synchronously (cached session if available)
    return client?.auth.currentUser?.id.uuidString
}

func saveUserName() {
    UserDefaults.standard.set(name, forKey: "userName")
}

func getUsername() async throws -> String? {
    guard let client = SupabaseClientManager.shared.client else { return nil }
    
    let profile: Profile? = try await client
        .from("profiles")
        .select("id, name")
        .eq("id", value: client.auth.currentUser?.id)
        .single()
        .execute()
        .value
    
    return profile?.name
}

// Date utility for PostgreSQL date formats
func dateFromPostgreSQL(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: dateString)
}

// Utility to get today's date as Date object
func todayDate() -> Date {
    return Date()
}

// Utility to convert any Date to PostgreSQL string format
func dateToPostgreSQLString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

// returns string of current month of give date
func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
