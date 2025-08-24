import SwiftUI

struct AppRouter: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentUserUUID: String = ""

    var body: some View {
        NavigationStack {
            TabView {
                TaskView()
                    .tabItem { Label("Task", systemImage: "house") }

                TrackerView()
                    .tabItem { Label("Tracker", systemImage: "calendar") }

                ChallengeView()
                    .tabItem { Label("Challenge", systemImage: "flame") }

                CommunityView()
                    .tabItem { Label("Community", systemImage: "person.3.sequence.fill") }

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                    .environmentObject(authViewModel)
            }
            .task {
                // Fetch logged-in user's UUID
                guard let client = SupabaseClientManager.shared.client else { return }
                if let session = try? await client.auth.session {
                    currentUserUUID = session.user.id.uuidString
                }
            }
        }
    }
}
