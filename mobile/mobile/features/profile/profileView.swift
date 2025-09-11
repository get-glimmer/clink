import SwiftUI
import Supabase
import PhotosUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Temporary state for editing
    @State private var newName: String = ""
    @State private var newBio: String = ""
    @State private var newAvatarURL: String = ""
    
    // Photo picker state
    @State private var showImagePicker = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil   // Optimistic UI
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)
                
                // MARK: - Avatar (tap to change)
                Button {
                    showImagePicker = true
                } label: {
                    if let selectedImage = selectedImage {
                        // ✅ Show picked image immediately
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else if let avatar = viewModel.profile?.avatar_url,
                              let url = URL(string: "\(avatar)?t=\(Date().timeIntervalSince1970)") {
                        // ✅ Cache-busting by appending timestamp
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
                }
                .buttonStyle(.plain)
                .photosPicker(
                    isPresented: $showImagePicker,
                    selection: $selectedItem,
                    matching: .images
                )
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data),
                           let session = try? await SupabaseClientManager.shared.client?.auth.session {
                            
                            // Show local preview instantly
                            selectedImage = image
                            
                            // Upload to Supabase
                            let userId = session.user.id.uuidString
                            await authViewModel.updateAvatar(userId: userId, profileImage: image)
                        }
                    }
                }




                VStack(spacing: 4) {
                    Text(viewModel.profile?.name ?? "")
                        .font(.title2)
                        .bold()
                        .foregroundColor(Color("White"))
                    
                    Text(viewModel.profile?.email ?? "")
                        .font(.caption)
                        .foregroundColor(Color("Neutral-300"))
                }
                
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
                        
                        NavigationLink(destination: SettingsView().environmentObject(authViewModel)) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .task {
                guard let client = SupabaseClientManager.shared.client else { return }
                if let session = try? await client.auth.session {
                    let userId = session.user.id.uuidString
                    await viewModel.fetchProfile(uuid: userId)
                    
                    newName = viewModel.profile?.name ?? ""
                    newBio = viewModel.profile?.bio ?? ""
                    newAvatarURL = viewModel.profile?.avatar_url ?? ""
                }
            }
        }
    }
}
