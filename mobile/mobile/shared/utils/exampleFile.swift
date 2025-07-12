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
