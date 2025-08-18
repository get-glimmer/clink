import SwiftUI

struct AppRouter: View {
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
    }
}

#Preview {
    RootView()
}
