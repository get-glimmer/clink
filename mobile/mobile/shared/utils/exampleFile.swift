import Foundation

let hardcodedUserId = "f221d19a-9da8-44eb-b14c-d4a315c23d85"
let name = "Cicero"
let avatar_url = "https://picsum.photos/200/300"

func saveUserId() {
    UserDefaults.standard.set(hardcodedUserId, forKey: "userId")
}

func getUserId() -> String? {
    return UserDefaults.standard.string(forKey: "userId")
}

func saveUserName() {
    UserDefaults.standard.set(name, forKey: "userName")
}

func getUserName() -> String? {
    return UserDefaults.standard.string(forKey: "userName")
}

// Date utility for PostgreSQL date formats
func dateFromPostgreSQL(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: dateString)
}

// Utility to get today's date as yyyy-MM-dd string
func todayString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}

// returns string of current month of give date
func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
