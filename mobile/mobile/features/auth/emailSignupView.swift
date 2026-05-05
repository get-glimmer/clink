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
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()
            
            VStack {
                // Custom top navigation bar
                TopNavBar(title: "Sign up") {
                    dismiss()
                }
                
                ScrollView {
                    VStack(alignment: .leading) {
                        // Email input field
                        VStack(alignment: .leading) {
                            Text("Email")
                                .appFont(AppFont.labelL)
                                .foregroundColor(.white)
                                .padding(.leading, 7)
                                .padding(.top, 24)
                                .padding(.bottom, 6)
                            
                            TextField("Email Address", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .frame(height: 49)
                                .padding(.leading, 18)
                                .appFont(AppFont.body1)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("Neutral-600"), lineWidth: 0.7))
                                .onChange(of: email) { _, newValue in
                                    email = newValue.lowercased()
                                    emailError = nil
                                }
                            
                            if let error = emailError {
                                Text(error)
                                    .appFont(AppFont.captionS)
                                    .foregroundColor(Color("Red-300"))
                                    .padding(.leading, 7)
                                    .padding(.top, 2)
                            }
                        }
                        
                        
                        // Password input field
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Password")
                                .appFont(AppFont.labelL)
                                .foregroundColor(.white)
                                .padding(.leading, 7)
                                .padding(.top, 24)
                                .padding(.bottom, 6)
                            
                            ZStack(alignment: .trailing) {
                                Group {
                                    if showPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .frame(height: 49)
                                .padding(.leading, 18)
                                .appFont(AppFont.body1)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("Neutral-600"), lineWidth: 0.7))
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(showPassword ? "myEye-off" : "myEye")
                                        .resizable()
                                            .scaledToFit()
                                            .frame(width: 24, height: 24)
                                        .foregroundColor(Color("Neutral-200"))
                                        .padding(.trailing, 12)
                                }
                            }
                            
                            // Password requirements display
                            let reqs = authViewModel.passwordRequirements(password)
                            VStack(alignment: .leading) {
                                Text("Your password must include the following")
                                    .appFont(AppFont.captionS)
                                    .foregroundColor(Color("Neutral-100"))
                                    .padding(.top, 16)
                                    .padding(.bottom, 6)
                                
                                passwordRequirementRow("Minimum 8 characters", check: reqs.min8)
                                passwordRequirementRow("At least one number", check: reqs.number)
                                passwordRequirementRow("Upper & lowercase letters", check: reqs.upperLower)
                            }
                            .padding(.leading, 7)
                        }
                    }
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
                            emailError = "This email is already in use"
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
                    HStack(alignment: .center, spacing: 10) {
                        Text("Continue")
                            .appFont(AppFont.buttonL)
                            .foregroundColor(!email.isEmpty && authViewModel.validatePassword(password) ? Color("Neutral-900") : Color("Neutral-600"))
                    }
                    .padding(.horizontal, 29)
                    .padding(.vertical, 13)
                    .frame(width: 361, height: 50, alignment: .center)
                    .background(!email.isEmpty && authViewModel.validatePassword(password) ? Color("Green-300") : Color("Neutral-800"))
                    .cornerRadius(8)
                }
                .padding(.bottom, 16)
                .disabled(email.isEmpty || !authViewModel.validatePassword(password))
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .padding(.horizontal, 16)
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
        }
        .dismissKeyboardOnTap()
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
        HStack(spacing: 8) {
            Image(check ? "checkboxPasswordFilled" : "checkboxPasswordEmpty")
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
            Text(text)
                .foregroundColor(.white)
                .appFont(AppFont.captionS)
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
