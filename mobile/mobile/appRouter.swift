import SwiftUI

struct AppRouter: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            HomeView()
                .tabItem {
                    Label("Home1", systemImage: "house")
                }
        }
    }
}
