import SwiftUI
import PhotosUI
import Supabase

/**
 * A view for users to complete their profile information after signing up.
 */
struct FinishSignupView: View {
    // MARK: - Properties

    /// The user's phone number, if available.
    let phoneNumber: String?

    /// The user's email address, if available.
    let email: String?

    /// The user's password, if available.
    let password: String?

    /// The user's unique identifier, if available.
    let userId: String?
    
    // MARK: - Environment and State

    /// The navigation path for programmatic navigation.
    @Binding var path: NavigationPath

    /// The authentication view model from the environment.
    @EnvironmentObject var authViewModel: AuthViewModel

    /// The presentation mode of the view.
    @Environment(\.dismiss) var dismiss

    /// The user's full name.
    @State private var fullName: String = ""

    /// The user's chosen username.
    @State private var username: String = ""

    /// The user's date of birth.
    @State private var dateOfBirth: Date = Date()

    /// A boolean to control the visibility of the date picker.
    @State private var showDatePicker = false

    /// The user's selected profile image.
    @State private var profileImage: UIImage?

    /// A boolean to indicate if a network request is in progress.
    @State private var isLoading = false

    /// The selected item from the photo picker.
    @State private var photoItem: PhotosPickerItem?

    /// A boolean to indicate if the chosen username is confirmed to be available.
    @State private var usernameConfirmed: Bool = false

    /// The status message for the username availability check.
    @State private var usernameStatus: String? = nil

    /// The color of the username status message.
    @State private var usernameStatusColor: Color = .white
    
    /// A boolean to track if the user has selected a date of birth.
    @State private var hasSelectedDate = false

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
                            }
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
                                    .frame(maxHeight: .infinity)
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
                            showDatePicker = true
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
                        .sheet(isPresented: $showDatePicker) {
                            VStack {
                                Text("Select your birthdate")
                                    .font(.headline)
                                    .padding()

                                DatePicker(
                                    "",
                                    selection: $dateOfBirth,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .padding()

                                Button("Done") {
                                    hasSelectedDate = true
                                    showDatePicker = false
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                                .padding()
                            }
                            .presentationDetents([.medium])
                        }

                        Text("Your birthday won't be shared with other people.")
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
                    guard let client = SupabaseClientManager.shared.client else { return }

                    var finalUserId: String?

                    // If signing up with email, create the user now
                    if let email, let password {
                        do {
                            let result = try await client.auth.signUp(email: email, password: password)
                            finalUserId = result.user.id.uuidString
                        } catch {
                            print("❌ Email signup failed:", error.localizedDescription)
                        }
                    }

                    // If signing up with phone, the user already exists
                    if let uid = userId {
                        finalUserId = uid
                    }

                    // Save the profile if a user ID is available
                    if let finalUserId {
                        await authViewModel.saveProfile(
                            userId: finalUserId,
                            phoneNumber: phoneNumber,
                            name: fullName,
                            username: username,
                            dob: dateOfBirth,
                            profileImage: profileImage,
                            email: email
                        )

                        path.append(Screen.signupSuccess)
                    }

                    isLoading = false
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((!usernameConfirmed || fullName.isEmpty) ? Color("Neutral-800") : Color("Green-300"))
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .padding()
            }
            .disabled(!usernameConfirmed || fullName.isEmpty)
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
    }
}
