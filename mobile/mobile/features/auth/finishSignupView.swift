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


    // MARK: - Body

    var body: some View {
        // Custom top navigation bar
        TopNavBar(title: "Finish signing up") {
            dismiss()
        }
        
        VStack {
            ScrollView {
                VStack {
                    // Profile avatar picker
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        if let profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 84, height: 84)
                                .clipShape(Circle())
                        } else {
                            Image("profile_picker")
                        }
                    }
                    .padding(.top, 49)
                    .onChange(of: photoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                profileImage = uiImage
                                showCropper = true
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
                                        usernameStatusColor = .white
                                        usernameConfirmed = true
                                    } else {
                                        usernameStatus = "The username is already in use."
                                        usernameStatusColor = Color("Red- 300")
                                        usernameConfirmed = false
                                    }
                                }
                            } label: {
                                Text("Confirm")
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
                                .font(.caption)
                                .foregroundColor(usernameStatusColor)
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
                                        .foregroundColor(.white)
                                } else {
                                    Text("Birthdate")
                                        .padding(.leading, 18)
                                        .appFont(AppFont.body1)
                                        .foregroundColor(Color("Neutral-600"))
                                }
                                Spacer()
                                Image("down_arrow")
                                    .padding(.trailing, 12)
                                    .foregroundColor(Color("Neutral-300"))
                            }
                            .frame(height: 49)
                            .padding(.top, 4)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .inset(by: 0.35)
                                    .stroke(Color("Neutral-600"), lineWidth: 0.7))
                        }
                        
                        .overlay(alignment: .bottomLeading) {
                            if showChangeDateSheet {
                                ChangeDateSheet(
                                    initialDate: todayDate(),
                                    onConfirm: { picked in
                                        dateOfBirth = picked
                                        hasSelectedDate = true
                                        showChangeDateSheet = false
                                    },
                                    onCancel: { showChangeDateSheet = false }
                                )
                                .transition(.opacity)
                                .ignoresSafeArea()
                            }
                        }
                        .animation(.easeInOut(duration: 0.25), value: showChangeDateSheet)

                        Text("Your birthday won’t be shared with other people who use Clink!.")
                            .appFont(AppFont.captionXS)
                            .padding(.top, 8)
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
                            
                            // Step 2: Immediately sign in to establish a session.
                            // This is the key to creating a seamless login experience.
                            try await client.auth.signIn(email: email, password: password)
                            
                            // If both succeed, get the user ID and mark as successful
                            finalUserId = signUpResult.user.id.uuidString
                            authSuccessful = true
                        } catch {
                            print("❌ Email signup or sign-in failed:", error.localizedDescription)
                            authSuccessful = false
                        }
                    } else if let uid = userId { // Phone signup flow
                        finalUserId = uid
                        authSuccessful = true // User is already authenticated in this flow
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
                        .appFont(AppFont.body1)
                        .foregroundColor((!usernameConfirmed || fullName.isEmpty)
                                         ? Color("Neutral-600")
                                         : Color("Neutral-900"))
                }
                .padding(.horizontal, 29)
                .padding(.vertical, 13)
                .frame(width: 361, alignment: .center)
                .background((!usernameConfirmed || fullName.isEmpty)
                            ? Color("Neutral-800")
                            : Color("Green-300"))
                .cornerRadius(8)
            }
            
            .disabled(!usernameConfirmed || fullName.isEmpty)
        }
        .padding(.horizontal, 16)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
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
