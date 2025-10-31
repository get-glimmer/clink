import SwiftUI

/**
 * A view for users to log in with their email and password.
 */
struct EmailLoginView: View {
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

    /// A boolean to indicate if a network request is in progress.
    @State private var isLoading = false

    /// A boolean to control the visibility of an alert.
    @State private var showAlert = false

    /// The message to display in the alert.
    @State private var alertMessage = ""

    // MARK: - Body

    var body: some View {
        ZStack {
            Color("Neutral-1000").ignoresSafeArea()
            
            VStack  {
                TopNavBar(title: "Log in") {
                    dismiss()
                }
                
                // Email input field
                VStack(alignment: .leading) {
                    Text("Email")
                        .appFont(AppFont.labelL)
                        .foregroundColor(.white)
                        .padding(.leading, 7)
                        .padding(.top, 24)
                    
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .frame(height: 49)
                        .padding(.leading, 18)
                        .appFont(AppFont.body1)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("Neutral-600"), lineWidth: 0.7))
                        .onChange(of: email) { _, newValue in
                            email = newValue.lowercased()
                        }
                }
                
                
                // Password input field
                VStack(alignment: .leading) {
                    Text("Password")
                        .appFont(AppFont.labelL)
                        .foregroundColor(.white)
                        .padding(.top, 24)
                        .padding(.leading, 7)
                    
                    SecureField("Password", text: $password)
                        .appFont(AppFont.body1)
                        .frame(height: 49)
                        .padding(.leading, 18)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("Neutral-600"), lineWidth: 0.7))
                    
                    // Forgot password button
                    HStack {
                        Button {
                            Task {
                                let success = await authViewModel.resetPassword(for: email)
                                alertMessage = success
                                    ? "Password reset email sent to \(email)"
                                    : "Please enter a valid email address."
                                showAlert = true
                            }
                        } label: {
                            Text("Forgot your password?")
                                .underline(true, color: .white)
                                .font(.caption)
                                .foregroundColor(.white)
                                // 👇 This keeps the tap area tight around the text
                                .contentShape(Rectangle())
                        }
                        Spacer() // Pushes the text to the leading edge
                    }
                    .padding(.top, 5)
                    .padding(.leading, 5)
                }
                
                // Error message display
                if !authViewModel.errorMessage.isEmpty {
                    Text(authViewModel.errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 5)
                }
                
                Spacer()
                
                // Link to the sign-up view
                HStack {
                    Text("Don't have an account?")
                        .appFont(AppFont.captionM)
                        .foregroundColor(Color("Neutral-600"))
                    
                    Button {
                        path.append(Screen.emailSignup)
                    } label: {
                        Text("Sign up")
                            .appFont(AppFont.captionM)
                            .underline(true, color: .white)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Continue button
                Button {
                    Task {
                        isLoading = true
                        authViewModel.email = email.lowercased()
                        authViewModel.password = password
                        await authViewModel.logIn()
                        isLoading = false
                    }
                } label: {
                    Text(isLoading ? "Logging in..." : "Continue")
                        .appFont(AppFont.buttonL)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(!email.isEmpty && !password.isEmpty ? Color("Green-300") : Color("Neutral-800"))
                        .foregroundColor(!email.isEmpty && !password.isEmpty ? Color("Neutral-900") : Color("Neutral-600"))
                        .cornerRadius(12)
                }
                .padding(.bottom, 16)
                .disabled(email.isEmpty || password.isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
        }
        .dismissKeyboardOnTap()
    }
}

struct EmailLoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EmailLoginView(path: .constant(NavigationPath()))
                .environmentObject(AuthViewModel()) // Provide a mock or real instance
                .preferredColorScheme(.dark)        // Optional: dark mode preview
        }
    }
}
