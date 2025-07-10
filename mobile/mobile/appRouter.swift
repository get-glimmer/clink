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

struct AppRouterPreview: PreviewProvider {
    static var previews: some View {
        AppRouter()
    }
}
