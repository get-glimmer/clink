import SwiftUI
import PhotosUI
import Supabase

/**
 * A view for users to complete their profile information after signing up.
 */
struct FinishSignupView: View {
    // MARK: - Properties

    let phoneNumber: String?
    let email: String?
    let password: String?
    let userId: String?
    
    // MARK: - Environment and State

    @Binding var path: NavigationPath
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var showChangeDateSheet = false
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    @State private var photoItem: PhotosPickerItem?
    @State private var usernameConfirmed: Bool = false
    @State private var usernameStatus: String? = nil
    @State private var usernameStatusColor: Color = .white
    @State private var hasSelectedDate = false
    @State private var showCropper = false
    
    // Photo picker state
    @State private var showImagePicker = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil   // Optimistic UI
    
    @State private var showVerificationAlert = false
    @State private var navigateBackToLogin = false



    // MARK: - Body

    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()
            
            VStack {
                // Custom top navigation bar
                TopNavBar(title: "Finish signing up") {
                    dismiss()
                }
                
                ScrollView {
                    VStack {
                        // Profile avatar picker
                        Button {
                            showImagePicker = true
                        } label: {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let avatar = authViewModel.profile?.avatar_url,
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
                        .padding(.top, 47)
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
                                // ✅ Reset selection so user can reselect the same photo later
                                selectedItem = nil
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
                        
                        // Full name input field
                        VStack(alignment: .leading) {
                            Text("Your name")
                                .padding(.leading, 11)
                                .appFont(AppFont.labelS)
                                .foregroundColor(Color("Neutral-300"))
                            
                            TextField("Full name", text: $fullName)
                                .padding(.leading, 18)
                                .appFont(AppFont.body1)
                                .background(Color.clear)
                                .frame(maxWidth: .infinity, minHeight: 49)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .inset(by: 0.35)
                                        .stroke(Color("Neutral-600"), lineWidth: 0.7)
                                )
                        }
                        .padding(.top, 23)
                        
                        
                        // Username input field and confirmation
                        VStack(alignment: .leading) {
                            Text("Username")
                                .padding(.leading, 11)
                                .appFont(AppFont.labelS)
                                .foregroundColor(Color("Neutral-300"))
                            
                            HStack() {
                                TextField("Username", text: $username)
                                    .padding(.leading, 18)
                                    .appFont(AppFont.body1)
                                    .background(Color.clear)
                                    .frame(maxWidth: .infinity, minHeight: 49)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .inset(by: 0.35)
                                            .stroke(Color("Neutral-600"), lineWidth: 0.7)
                                    )
                                    .onChange(of: username) {
                                        usernameConfirmed = false
                                        usernameStatus = nil
                                    }
                                
                                Button {
                                    Task {
                                        if await authViewModel.checkUsername(username) {
                                            usernameStatus = "The username is available."
                                            usernameStatusColor = Color("Neutral-100")
                                            usernameConfirmed = true
                                        } else {
                                            usernameStatus = "The username is already in use."
                                            usernameStatusColor = Color("Red-300")
                                            usernameConfirmed = false
                                        }
                                    }
                                } label: {
                                    Text("Confirm")
                                        .appFont(AppFont.buttonL)
                                        .frame(width: 119, height: 50)
                                        .foregroundColor(username.isEmpty ? .white : Color("Neutral-900"))
                                    
                                        .background(username.isEmpty ? Color("Neutral-800") : Color("Green-300"))
                                        .cornerRadius(8)
                                }
                                .disabled(username.isEmpty)
                            }
                            .frame(height: 50)
                            
                            if let status = usernameStatus {
                                Text(status)
                                    .appFont(AppFont.captionXS)
                                    .foregroundColor(usernameStatusColor)
                                    .padding(.leading, 7)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.top, 16)
                        
                        // Date of birth picker
                        VStack(alignment: .leading) {
                            Text("Date of Birth (Optional)")
                                .padding(.leading, 11)
                                .appFont(AppFont.labelS)
                                .foregroundColor(Color("Neutral-300"))
                            
                            Button {
                                showChangeDateSheet = true
                            } label: {
                                HStack {
                                    if hasSelectedDate {
                                        Text(dateOfBirth, style: .date)
                                            .appFont(AppFont.body1)
                                            .foregroundColor(.white)
                                            .padding(.leading, 18)
                                            .frame(maxHeight: .infinity, alignment: .center)
                                    } else {
                                        Text("Birthdate")
                                            .appFont(AppFont.body1)
                                            .foregroundColor(Color("Neutral-600"))
                                            .padding(.leading, 18)
                                            .frame(maxHeight: .infinity, alignment: .center)
                                    }

                                    Spacer()

                                    Image("down_arrow")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(Color("Neutral-300"))
                                        .padding(.trailing, 12)
                                        .frame(maxHeight: .infinity, alignment: .center)
                                }
                                .frame(height: 49)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .inset(by: 0.35)
                                        .stroke(Color("Neutral-600"), lineWidth: 0.7))
                            }
                            .fullScreenCover(isPresented: $showChangeDateSheet) {
                                if showChangeDateSheet {
                                    ChangeDateSheet(
                                        initialDate: todayDate(),
                                        onConfirm: { picked in
                                            dateOfBirth = picked
                                            hasSelectedDate = true
                                            showChangeDateSheet = false
                                        },
                                        onCancel: {
                                            showChangeDateSheet = false
                                        }
                                    )
                                    .transition(.opacity)
                                    .ignoresSafeArea()
                                    .zIndex(10)
                                }
                            }
                            .animation(.easeInOut(duration: 0.25), value: showChangeDateSheet)
                            
                            Text("Your birthday won’t be shared with other people who use Clink!.")
                                .appFont(AppFont.captionXS)
                                .padding(.top, 4)
                                .padding(.leading, 7)
                                .foregroundColor(Color("Neutral-400"))
                        }
                        .padding(.top, 16)
                    }
                }
                // Continue button
                Button {
                    Task {
                        isLoading = true
                        guard let client = SupabaseClientManager.shared.client else {
                            print("Supabase client not available.")
                            isLoading = false
                            return
                        }
                        
                        var finalUserId: String?
                        var authSuccessful = false
                        
                        // --- Part 1: Authenticate and get User ID ---
                        if let email, let password { // Email signup flow
                            do {
                                // Step 1: Create the user in auth.users
                                let signUpResult = try await client.auth.signUp(email: email, password: password)
                                
                                // Step 3: Notify the user
                                await MainActor.run {
                                    isLoading = false
                                    // Show alert or navigate to login
                                    showVerificationAlert = true
                                }
                                // Give SwiftUI a moment to catch the alert state before returning
                                try? await Task.sleep(nanoseconds: 300_000_000)
//                                return  // Stop here — don’t auto sign in
                            } catch {
                                print("❌ Email signup failed:", error.localizedDescription)
                                authSuccessful = false
                            }
                        }

                        
                        // --- Part 2: Save Profile and Transition ---
                        if authSuccessful, let finalUserId {
                            // Step 3: Save the profile data (name, username, etc.)
                            await authViewModel.saveProfile(
                                userId: finalUserId,
                                phoneNumber: phoneNumber,
                                name: fullName,
                                username: username,
                                dob: dateOfBirth,
                                profileImage: profileImage,
                                email: email
                            )
                            
                            // Step 4: Set isAuthenticated to true. This will trigger the
                            // view switch in your main AppRouter/ContentView.
                            authViewModel.isAuthenticated = true
                        } else {
                            // Handle the signup failure case. You could show an alert here.
                            print("Authentication process failed. Staying on the current screen.")
                        }
                        
                        isLoading = false
                    }
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Continue")
                            .appFont(AppFont.buttonL)
                            .foregroundColor((!usernameConfirmed || fullName.isEmpty)
                                             ? Color("Neutral-600")
                                             : Color("Neutral-900"))
                    }
                    .padding(.horizontal, 29)
                    .padding(.vertical, 13)
                    .frame(width: 361, height: 50, alignment: .center)
                    .background((!usernameConfirmed || fullName.isEmpty)
                                ? Color("Neutral-800")
                                : Color("Green-300"))
                    .cornerRadius(8)
                }
                .disabled(!usernameConfirmed || fullName.isEmpty)
                .padding(.bottom, 16)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .padding(.horizontal, 16)
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
        }
        .alert("Check your email", isPresented: $showVerificationAlert) {
            Button("OK") {
                print("[FinishSignupView] setting authViewModel.shouldResetLoginFlow = true")
                authViewModel.shouldResetLoginFlow = true
            }
        } message: {
            Text("A verification link has been sent to \(email ?? "your email"). Please verify your account before logging in.")
        }


        .dismissKeyboardOnTap()
    }
}

struct FinishSignupView_Previews: PreviewProvider {
    static var previews: some View {
        
        // MARK: - Preview for Email Signup Flow
        
        // This preview simulates the state where a user has entered
        // an email and password on the previous screen.
        NavigationStack {
            FinishSignupView(
                phoneNumber: nil,
                email: "test@example.com",
                password: "password123",
                userId: nil,
                path: .constant(NavigationPath()) // Provides a constant binding for the preview
            )
            .environmentObject(AuthViewModel()) // Injects a mock AuthViewModel
            .preferredColorScheme(.dark)
        }
        .previewDisplayName("Email Signup Flow")
        
        
        // MARK: - Preview for Phone Signup Flow
        
        // This preview simulates the state where a user has already
        // authenticated with their phone number and received a user ID.
        NavigationStack {
            FinishSignupView(
                phoneNumber: "123-456-7890",
                email: nil,
                password: nil,
                userId: "a1b2c3d4-e5f6-7890-1234-567890abcdef", // Example mock user ID
                path: .constant(NavigationPath())
            )
            .environmentObject(AuthViewModel())
            .preferredColorScheme(.dark)
        }
        .previewDisplayName("Phone Signup Flow")
    }
}
