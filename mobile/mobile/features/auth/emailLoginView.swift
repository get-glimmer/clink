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
        // Custom top navigation bar
        TopNavBar(title: "Log in") {
            dismiss()
        }
        
        VStack (spacing: 35) {
            // Email input field
            VStack(alignment: .leading, spacing: 5) {
                Text("Email")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.leading, 5)
                    .padding(.top, 10)
                
                TextField("Email address", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                    .onChange(of: email) { _, newValue in
                        email = newValue.lowercased()
                    }
            }
            
            // Password input field
            VStack(alignment: .leading, spacing: 5) {
                Text("Password")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.leading, 5)
                
                SecureField("Password", text: $password)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                
                // Forgot password button
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 5)
                        .padding(.leading, 5)
                }
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
                    .foregroundColor(Color("Neutral-600"))
                
                Button {
                    path.append(Screen.emailSignup)
                } label: {
                    Text("Sign up")
                        .underline(true, color: .white)
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(!email.isEmpty && !password.isEmpty ? Color("Green-300") : Color("Neutral-800"))
                    .foregroundColor(!email.isEmpty && !password.isEmpty ? Color("Neutral-900") : Color("Neutral-600"))
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
        }
        .padding()
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
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
