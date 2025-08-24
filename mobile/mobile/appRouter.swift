import SwiftUI

struct AppRouter: View {
    @State private var currentUserUUID: String = ""

    var body: some View {
        TabView {
            TaskView()
                .tabItem {
                    Label("Task", systemImage: "house")
                }
            TrackerView()
                .tabItem {
                    Label("Tracker", systemImage: "calendar")
                }
            ChallengeView()
                .tabItem {
                    Label("Challenge", systemImage: "flame")
                }
            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.3.sequence.fill")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
        }
        .task {
            // Fetch logged-in user's UUID
            if let client = SupabaseClientManager.shared.client,
               let user = try? await client.auth.session.user {
                currentUserUUID = user.id.uuidString
            }
        }
    }
}


