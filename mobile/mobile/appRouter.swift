import SwiftUI

struct AppRouter: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentUserUUID: String = ""
    @State private var selectedTab: Tab = .task
    @State private var isCommunityMenuPresented: Bool = false
    @State private var isNavHidden: Bool = false
    
    enum Tab: Hashable { case task, tracker, challenge, community, profile }

        // Hide system tab bar globally
        init() {
            UITabBar.appearance().isHidden = true
        }

        var body: some View {
            ZStack {
                TabView(selection: $selectedTab) {
                    TaskView().tag(Tab.task)
                    TrackerView().tag(Tab.tracker)
                    ChallengeView().tag(Tab.challenge)
                    CommunityView(isMenuPresented: $isCommunityMenuPresented).tag(Tab.community)
                    ProfileView().tag(Tab.profile)
                }
                .onPreferenceChange(NavBarHiddenPreferenceKey.self) { value in
                    isNavHidden = value // If any active child requests hiding
                }

                VStack {
                    Spacer()
                    CustomNavBar(selectedTab: $selectedTab)
                }
                .ignoresSafeArea(.keyboard)
                // Hide nav
                .opacity(shouldHideNavBar ? 0 : 1)
                .zIndex(shouldHideNavBar ? 0 : 1)
            }
        }
    private var shouldHideNavBar: Bool {
        isCommunityMenuPresented || isNavHidden
    }
    
}

struct CustomNavBar: View {
    @Binding var selectedTab: AppRouter.Tab

    private let greenTint = Color(hex: "00FFAA") ?? .clear
    
    var body: some View {
        HStack(spacing: 5.06) {
            navItem(.task, imageName: "task")
            Spacer(minLength: 0)
            navItem(.tracker, imageName: "tracker")
            Spacer(minLength: 0)
            navItem(.challenge, imageName: "challenge")
            Spacer(minLength: 0)
            navItem(.community, imageName: "community")
            Spacer(minLength: 0)
            navItem(.profile, imageName: "profile")
        }
        .ignoresSafeArea(.keyboard)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .frame(height: 65)
        // liquid glass background
        .liquidGlass(
            cornerRadius: 50,
            tint: greenTint,
            tintOpacity: 0.5
        )
        .padding(.horizontal, 16)
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
                .frame(width: 45.1, height: 45.1)
                .foregroundColor(Color("White"))
                .opacity(selectedTab == tab ? 1.0 : 0.7)
        }
    }
}
