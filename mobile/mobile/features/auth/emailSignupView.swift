import SwiftUI

/**
 * A view for users to sign up with their email and password.
 */
struct EmailSignupView: View {
    // MARK: - Environment and State

    /// The authentication view model from the environment.
    @EnvironmentObject var authViewModel: AuthViewModel

    /// The navigation path for programmatic navigation.
    @Binding var path: NavigationPath

    /// The presentation mode of the view.
    @Environment(\.dismiss) var dismiss

    /// The user's email address.
    @State private var email = ""

    /// The user's password.
    @State private var password = ""

    /// A boolean to toggle password visibility.
    @State private var showPassword = false

    /// A boolean to indicate if a network request is in progress.
    @State private var isLoading = false

    /// An optional string to display an error message for the email field.
    @State private var emailError: String? = nil

    // MARK: - Body

    var body: some View {
        VStack {
            ScrollView {
                // Custom top navigation bar
                TopNavBar(title: "Sign up") {
                    dismiss()
                }
                
                VStack(alignment: .leading, spacing: 35) {
                    // Email input field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Email")
                            .appFont(AppFont.labelL)
                            .foregroundColor(.white)
                            .padding(.leading, 10)
                            .padding(.top, 10)
                        
                        TextField("Email Address", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .padding()
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                            .onChange(of: email) { _, newValue in
                                email = newValue.lowercased()
                                emailError = nil
                            }

                        if let error = emailError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 5)
                        }
                    }
                    
                    // Password input field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Password")
                            .appFont(AppFont.labelL)
                            .foregroundColor(.white)
                            .padding(.leading, 10)
                        
                        ZStack(alignment: .trailing) {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .padding()
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(Color("Neutral-200"))
                                    .padding()
                            }
                        }
                        
                        // Password requirements display
                        let reqs = authViewModel.passwordRequirements(password)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your password must include the following")
                                .appFont(AppFont.captionXS)
                                .foregroundColor(Color("Neutral-100"))
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                                .padding(.leading, 5)
                            
                            passwordRequirementRow("Minimum 8 characters", check: reqs.min8)
                            passwordRequirementRow("At least one number", check: reqs.number)
                            passwordRequirementRow("Upper & lowercase letters", check: reqs.upperLower)
                        }
                        .padding(.leading, 5)
                    }
                }
                .padding()
            }
            
            // Continue button
            Button {
                guard authViewModel.validatePassword(password) else { return }
                guard SupabaseClientManager.shared.client != nil else { return }

                Task {
                    isLoading = true

                    if !authViewModel.validateEmail(email) {
                        emailError = "Please enter a valid email address"
                        isLoading = false
                        return
                    }

                    let inUse = await authViewModel.checkEmailInUse(email)

                    if inUse {
                        emailError = "Email is already in use"
                    } else {
                        emailError = nil
                        path.append(
                            Screen.finishSignup(
                                phoneNumber: nil,
                                email: email,
                                password: password,
                                userId: nil
                            )
                        )
                    }

                    isLoading = false
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(!email.isEmpty && authViewModel.validatePassword(password) ? Color("Green-300") : Color("Neutral-800"))
                    .foregroundColor(!email.isEmpty && authViewModel.validatePassword(password) ? Color("Neutral-900") : Color("Neutral-600"))
                    .cornerRadius(12)
                    .padding()
            }
            .disabled(email.isEmpty || !authViewModel.validatePassword(password))
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Private Methods

    /**
     * A helper view to display a password requirement row.
     * - Parameters:
     * - text: The requirement text.
     * - check: A boolean indicating if the requirement is met.
     * - Returns: A view representing the requirement row.
     */
    private func passwordRequirementRow(_ text: String, check: Bool) -> some View {
        HStack {
            Text(check ? Image("checkboxFilled") : Image("checkboxEmpty"))
            Text(text)
                .foregroundColor(.white)
                .appFont(AppFont.captionXS)
        }
    }
}

struct EmailSignupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EmailSignupView(path: .constant(NavigationPath()))
                .environmentObject(AuthViewModel()) // Provide a mock or real instance
                .preferredColorScheme(.dark)        // Optional: dark mode preview
        }
    }
}
