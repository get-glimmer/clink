import SwiftUI

// MARK: - Model

// Lightweight friend item used only for the invite picker.
struct FriendInviteItem: Identifiable {
    let id: String   // userId
    let username: String
    let avatarUrl: String?
}

// MARK: - ViewModel

@MainActor
class InviteFriendsViewModel: ObservableObject {
    @Published var friends: [FriendInviteItem] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false

    private let service = CommunityService()

    // Filters friends by username; returns all when search is empty.
    var filteredFriends: [FriendInviteItem] {
        guard !searchText.isEmpty else { return friends }
        return friends.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
    }

    // Reuses CommunityService to load the current user's accepted friends.
    func loadFriends() {
        isLoading = true
        Task {
            do {
                let loaded = try await service.getFriendsWithProgress()
                friends = loaded.map {
                    FriendInviteItem(id: $0.userId, username: $0.name, avatarUrl: $0.profileImageName)
                }
            } catch {
                print("[Challenges] ❌ InviteFriendsViewModel failed to load friends: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - View

struct InviteFriendsView: View {
    @Binding var invitedIds: Set<String>
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = InviteFriendsViewModel()

    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image("back_button")
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color("Neutral-900")))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Invite Friends")
                        .appFont(AppFont.title2)
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear.frame(width: 38, height: 38)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("Neutral-500"))

                    TextField("Search", text: $viewModel.searchText)
                        .appFont(AppFont.body1)
                        .foregroundColor(.white)

                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(Color("Neutral-500"))
                                .padding(6)
                                .background(Color("Neutral-700"))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color("Neutral-900"))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Friend list
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else if viewModel.filteredFriends.isEmpty {
                    Spacer()
                    Text(viewModel.searchText.isEmpty ? "No friends yet" : "No results")
                        .appFont(AppFont.captionM)
                        .foregroundColor(Color("Neutral-400"))
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(viewModel.filteredFriends) { friend in
                                let isInvited = invitedIds.contains(friend.id)

                                HStack(spacing: 12) {
                                    AvatarView(imageURLOrName: friend.avatarUrl, size: 44)

                                    Text(friend.username)
                                        .appFont(AppFont.labelM)
                                        .foregroundColor(.white)

                                    Spacer()

                                    Button {
                                        if isInvited {
                                            invitedIds.remove(friend.id)
                                        } else {
                                            invitedIds.insert(friend.id)
                                        }
                                    } label: {
                                        Text(isInvited ? "Invited" : "Invite")
                                            .appFont(AppFont.labelM)
                                            .foregroundColor(isInvited ? Color("Neutral-500") : .white)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                }
            }
        }
        .navBarHidden(true)
        .onAppear { viewModel.loadFriends() }
    }
}
