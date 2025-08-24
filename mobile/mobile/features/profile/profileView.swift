import SwiftUI
import Supabase

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    
    // Temporary state for editing
    @State private var newName: String = ""
    @State private var newBio: String = ""
    @State private var newAvatarURL: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // MARK: - Avatar
                if let avatar = viewModel.profile?.avatar_url, let url = URL(string: avatar) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                             .scaledToFill()
                             .frame(width: 100, height: 100)
                             .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay(Text("No Avatar"))
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(Text("No Avatar"))
                }

                // Name
                VStack(alignment: .leading) {
                    Text(viewModel.profile?.name ?? "Update your name")
                }
                
                // email
                VStack(alignment: .leading) {
                    Text(viewModel.profile?.email ?? "Update your email")
                }
                
                // Friends Count
                let count = viewModel.profile?.friendsCount ?? 0
                Text("\(count) friends")

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                }
            }
            .task {
                // Fetch current user's profile safely
                guard let client = SupabaseClientManager.shared.client else { return }
                if let session = try? await client.auth.session {
                    let userId = session.user.id.uuidString
                    await viewModel.fetchProfile(uuid: userId)
                    
                    // Populate edit fields with current profile data
                    newName = viewModel.profile?.name ?? ""
                    newBio = viewModel.profile?.bio ?? ""
                    newAvatarURL = viewModel.profile?.avatar_url ?? ""
                }
            }
        }
    }
}
