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
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Custom top navigation bar
                    TopNavBar(title: "Finish signing up") {
                        dismiss()
                    }

                    // Profile avatar picker
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        if let profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .padding(.top, 20)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color("Neutral-100"))
                            }
                            .padding(.top, 20)
                        }
                    }
                    .onChange(of: photoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                profileImage = uiImage
                                showCropper = true   // ⬅️ show cropper immediately after selection
                            }
                        }
                    }

                    .sheet(isPresented: $showCropper) {
                        if let image = profileImage {
                            CircleCropView(image: $profileImage)
                                .ignoresSafeArea()
                        }
                    }



                    // Full name input field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your name")
                            .font(.subheadline)
                            .foregroundColor(Color("Neutral-300"))

                        TextField("Full name", text: $fullName)
                            .padding()
                            .background(Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                            .cornerRadius(12)
                    }

                    // Username input field and confirmation
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundColor(Color("Neutral-300"))

                        HStack(spacing: 8) {
                            TextField("Username", text: $username)
                                .padding()
                                .background(Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                                .cornerRadius(12)
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
                                        usernameStatusColor = .red
                                        usernameConfirmed = false
                                    }
                                }
                            } label: {
                                Text("Confirm")
                                    .frame(width: 100, height: 55)
                                    .foregroundColor(username.isEmpty ? .white : Color("Neutral-900"))
                                    .padding(.horizontal, 16)
                                    .background(username.isEmpty ? Color("Neutral-800") : Color("Green-300"))
                                    .cornerRadius(12)
                            }
                            .disabled(username.isEmpty)
                        }
                        .frame(height: 55)

                        if let status = usernameStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(usernameStatusColor)
                                .padding(.leading, 4)
                        }
                    }

                    // Date of birth picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date of Birth (Optional)")
                            .font(.subheadline)
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
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(Color("Neutral-300"))
                            }
                            .padding()
                            .background(Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                            .cornerRadius(12)
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
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)
                    }
                }
                .padding()
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
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((!usernameConfirmed || fullName.isEmpty) ? Color("Neutral-800") : Color("Green-300"))
                    .foregroundColor((!usernameConfirmed || fullName.isEmpty) ? .gray : .black)
                    .cornerRadius(12)
                    .padding()
            }
            .disabled(!usernameConfirmed || fullName.isEmpty)
        }
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
