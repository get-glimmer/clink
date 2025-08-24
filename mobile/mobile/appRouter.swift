import SwiftUI

struct AppRouter: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentUserUUID: String = ""
    @State private var selectedTab: Tab = .task
        enum Tab: Hashable { case task, tracker, community, profile }

        // Hide system tab bar globally
        init() {
            UITabBar.appearance().isHidden = true
        }

        var body: some View {
            ZStack {
                TabView(selection: $selectedTab) {
                    TaskView().tag(Tab.task)
                    TrackerView().tag(Tab.tracker)
                    CommunityView().tag(Tab.community)
                    ProfileView().tag(Tab.profile)
                }

                VStack {
                    Spacer()
                    CustomNavBar(selectedTab: $selectedTab)
                }
                .ignoresSafeArea(.keyboard)
            }
        }
    
}

struct CustomNavBar: View {
    @Binding var selectedTab: AppRouter.Tab

    private let greenTint = Color(hex: "00FFAA") ?? .clear
    
    var body: some View {
        HStack(spacing: 15) {
            navItem(.task, imageName: "task")
            Spacer(minLength: 0)
            navItem(.tracker, imageName: "tracker")
            Spacer(minLength: 0)
            navItem(.community, imageName: "community")
            Spacer(minLength: 0)
            navItem(.profile, imageName: "profile")
        }
        .ignoresSafeArea(.keyboard)
        .padding(.horizontal, 28)
        .frame(width: 361, height: 65)
        // liquid glass background
        .liquidGlass(
            cornerRadius: 50,
            tint: greenTint,
            tintOpacity: 0.5
        )
        .accessibilityElement(children: .contain)
    }
    
    @ViewBuilder
    private func navItem(_ tab: AppRouter.Tab, imageName: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(imageName)
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .foregroundColor(Color("White"))
                .opacity(selectedTab == tab ? 1.0 : 0.7)
        }
    }
}
