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
    @Published var joinedIds: Set<String> = []              // active members already in the challenge
    @Published var inviteStatusById: [String: String] = [:] // userId → invite status from DB

    private let service = CommunityService()
    private let client = SupabaseClientManager.shared.client

    // Filters friends by username; returns all when search is empty.
    var filteredFriends: [FriendInviteItem] {
        guard !searchText.isEmpty else { return friends }
        return friends.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
    }

    // Loads friends and, when a challengeId is provided, fetches current members + pending
    // invites from the DB to populate excludedIds.
    func load(challengeId: UUID?) {
        isLoading = true
        Task {
            do {
                let loaded = try await service.getFriendsWithProgress()
                friends = loaded.map {
                    FriendInviteItem(id: $0.userId, username: $0.name, avatarUrl: $0.profileImageName)
                }

                if let challengeId, let client {
                    struct MemberRow: Decodable { let user_id: String; let left_at: String? }
                    struct InviteRow: Decodable { let invitee_user_id: String?; let status: String }

                    let allMembers: [MemberRow] = try await client
                        .from("challenge_members")
                        .select("user_id, left_at")
                        .eq("challenge_id", value: challengeId.uuidString)
                        .execute()
                        .value

                    let members = allMembers.filter { $0.left_at == nil }

                    let invites: [InviteRow] = try await client
                        .from("challenge_invites")
                        .select("invitee_user_id, status")
                        .eq("challenge_id", value: challengeId.uuidString)
                        .execute()
                        .value

                    joinedIds = Set(members.map { $0.user_id.lowercased() })
                    inviteStatusById = Dictionary(uniqueKeysWithValues: invites.compactMap { row in
                        guard let uid = row.invitee_user_id?.lowercased() else { return nil }
                        return (uid, row.status)
                    })
                }
            } catch {
                print("[Challenges] ❌ InviteFriendsViewModel failed to load: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - View

struct InviteFriendsView: View {
    @Binding var invitedFriends: [String: String]   // friendId → message
    var challengeId: UUID? = nil                    // when editing, filters already-joined/invited
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = InviteFriendsViewModel()
    @State private var pendingFriend: FriendInviteItem? = nil

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
                                let isJoined     = viewModel.joinedIds.contains(friend.id.lowercased())
                                let dbStatus     = viewModel.inviteStatusById[friend.id.lowercased()]
                                let isInvited    = invitedFriends[friend.id] != nil
                                let isDisabled   = isJoined || dbStatus != nil || isInvited
                                let statusLabel: String = {
                                    if isJoined { return "Joined" }
                                    if isInvited { return "Invited" }
                                    if let s = dbStatus { return s.prefix(1).uppercased() + s.dropFirst() }
                                    return "Invite"
                                }()

                                HStack(spacing: 12) {
                                    AvatarView(imageURLOrName: friend.avatarUrl, size: 44)
                                        .opacity(isDisabled ? 0.5 : 1)

                                    Text(friend.username)
                                        .appFont(AppFont.labelM)
                                        .foregroundColor(isDisabled ? Color("Neutral-500") : .white)

                                    Spacer()

                                    Button {
                                        if isInvited {
                                            invitedFriends.removeValue(forKey: friend.id)
                                        } else {
                                            pendingFriend = friend
                                        }
                                    } label: {
                                        Text(statusLabel)
                                            .appFont(AppFont.labelM)
                                            .foregroundColor(Color("Neutral-500"))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isDisabled)
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
        .onAppear { viewModel.load(challengeId: challengeId) }
        .sheet(item: $pendingFriend) { friend in
            InviteMessageSheet(friend: friend) { message in
                invitedFriends[friend.id] = message
                pendingFriend = nil
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color("Neutral-900"))
        }
    }
}

// MARK: - Invite Message Sheet

private struct InviteMessageSheet: View {
    let friend: FriendInviteItem
    let onSend: (String) -> Void

    @State private var message: String = "Join me for this challenge.."
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invite \(friend.username)")
                .appFont(AppFont.title2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Add a Message")
                    .appFont(AppFont.captionM)
                    .foregroundColor(Color("Neutral-400"))

                // Use .font() directly — appFont applies .fixedSize(vertical:true)
                // which collapses the TextEditor's interactive area.
                TextEditor(text: $message)
                    .font(AppFont.body2.font)
                    .foregroundColor(Color("White"))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(height: 88)
                    .background(Color("Neutral-800"))
                    .cornerRadius(12)
                    .onChange(of: message) { newValue in
                        // Limit to 3 lines via newline count
                        let lines = newValue.components(separatedBy: "\n")
                        if lines.count > 3 {
                            message = lines.prefix(3).joined(separator: "\n")
                        }
                    }
            }

            Button {
                onSend(message)
                dismiss()
            } label: {
                Text("Send Invite")
                    .appFont(AppFont.labelL)
                    .foregroundColor(Color("Neutral-1000"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color("Green-300"))
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}
