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
    
    @State private var showShareSheet = false
    @State private var selectedAppearance = 2
    
    @State private var showCropper = false

    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Neutral-1000").ignoresSafeArea()
                VStack {
                    // MARK: - Setting Icon
                    HStack {
                        Spacer() // pushes the icon to the right
                        NavigationLink(destination: SettingsView().environmentObject(authViewModel)) {
                            Image("setting")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                        }
                    }
                    
                    // MARK: - Avatar (tap to change)
                    Button {
                        showImagePicker = true
                    } label: {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let avatar = viewModel.profile?.avatar_url,
                                  let url = URL(string: "\(avatar)?t=\(Date().timeIntervalSince1970)") {
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
                                .overlay(Text("No Avatar").appFont(AppFont.body2))
                        }
                    }
                    .padding(.top, 15)
                    .buttonStyle(.plain)
                    .photosPicker(
                        isPresented: $showImagePicker,
                        selection: $selectedItem,
                        matching: .images
                    )
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                                showCropper = true  // 👈 add this
                            }
                        }
                    }
                    .sheet(isPresented: $showCropper) {
                        CircularImageCropper(image: $selectedImage)
                            .onDisappear {
                                Task {
                                    if let selectedImage = selectedImage,
                                       let session = try? await SupabaseClientManager.shared.client?.auth.session {
                                        let userId = session.user.id.uuidString
                                        await authViewModel.updateAvatar(userId: userId, profileImage: selectedImage)
                                    }
                                }
                            }
                    }
                    
                    
                    
                    VStack() {
                        Text(viewModel.profile?.name ?? "")
                            .padding(.top, 12)
                            .appFont(AppFont.title2)
                            .bold()
                            .foregroundColor(Color("White"))
                        
                        Text(viewModel.profile?.email ?? "")
                            .padding(.top, 4)
                            .appFont(AppFont.body2)
                            .foregroundColor(Color("Neutral-300"))
                    }
                    
                    HStack {
                        let count = viewModel.profile?.friendsCount ?? 0
                        Image("friends")
                            .foregroundColor(Color("White"))
                        Text("\(count) friends")
                            .appFont(AppFont.body2)
                    }
                    .padding(.bottom, 42.5)
                    
                    //                Spacer().frame(height: 5)
                    
                    // Share App button
                    Button {
                        showShareSheet = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Get friends to try us :)")
                                //                                .padding(.top, 25)
                                    .padding(.bottom, 1)
                                    .appFont(AppFont.labelL)
                                    .foregroundColor(.white)
                                
                                Text("And get a free sticker!")
                                    .appFont(AppFont.body2)
                                    .foregroundColor(Color("Neutral-400"))
                            }
                            .padding(.leading, 26)
                            
                            Spacer()
                            
                            Image("arrow_right")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(Color("Neutral-400"))
                                .padding(.trailing, 16)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color("Neutral-900"))
                        .cornerRadius(16)
                    }
                    .sheet(isPresented: $showShareSheet) {
                        ShareSheet(items: ["Check out this app! Download it here: https://apps.apple.com/app/idYOUR_APP_ID"])
                    }
                    
                    // MARK: - Appearance Section
                    HStack {
                        Text("Appearance")
                            .appFont(AppFont.labelL)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.top, 23)
                    .padding(.leading, 6)
                    
                    HStack(spacing: 16) {
                        AppearanceBox(iconName: "System", title: "System", isSelected: selectedAppearance == 0) {
                            selectedAppearance = 0
                        }
                        AppearanceBox(iconName: "Light", title: "Light", isSelected: selectedAppearance == 1) {
                            selectedAppearance = 1
                        }
                        AppearanceBox(iconName: "Dark", title: "Dark", isSelected: selectedAppearance == 2) {
                            selectedAppearance = 2
                        }
                        
                    }
                    .padding(.top, 15)
                    Spacer()
                }
                .padding(.horizontal, 16)
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
//            .background(.neutral1000)
        }
    }
}


struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView()
                .environmentObject(AuthViewModel())
                .preferredColorScheme(.dark)
        }
    }
}
