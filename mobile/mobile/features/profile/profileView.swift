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
                Spacer().frame(height: 20)
                
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

                VStack(spacing: 4) {
                    // name
                    Text(viewModel.profile?.name ?? "")
                        .font(.title2)
                        .bold()
                        .foregroundColor(Color("White"))
                    
                    // email
                    Text(viewModel.profile?.email ?? "")
                        .font(.caption)
                        .foregroundColor(Color("Neutral-300"))
                }
                
                // Friends Count
                HStack {
                    let count = viewModel.profile?.friendsCount ?? 0
                    Image(systemName: "person.2")
                            .foregroundColor(Color("White"))
                    Text("\(count) friends")
                }
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color("Neutral-900"))
                            .frame(width: 40, height: 40)
                        
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20, alignment: .center)
                        }
                        .buttonStyle(PlainButtonStyle()) // optional: removes any extra styling
                    }
                    .frame(width: 40, height: 40)
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
