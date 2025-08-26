import SwiftUI

struct EmailLoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var path: NavigationPath
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Log in with Email")
                .font(.title2)
                .bold()
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(.subheadline)
                    .foregroundColor(.white)
                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray))
            }
            
            // Password field with label
            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundColor(.white)
                SecureField("Enter your password", text: $password)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray))
            }
            
            HStack {
                Button {
                    Task {
                        let success = await authViewModel.resetPassword(for: email)
                        alertMessage = success
                            ? "Password reset email sent to \(email)"
                            : "Put valid email on the email section"
                        showAlert = true
                    }
                } label: {
                    Text("Forgot password?")
                        .underline(true, color: .white)
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 10)
            
            // 🔴 Error message below password
            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
            }
            
            Spacer()
            
            // Sign up text
            HStack {
                Text("Don't have an account?")
                    .foregroundColor(.gray)
                Button("Sign up") {
                    path.append(Screen.emailSignup)
                }
                .foregroundColor(.blue)
            }
            
            // Continue button
            Button {
                Task {
                    isLoading = true
                    authViewModel.email = email
                    authViewModel.password = password
                    await authViewModel.logIn()
                    isLoading = false
                }
            } label: {
                Text(isLoading ? "Logging in..." : "Continue")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(email.isEmpty || password.isEmpty ? Color.gray : Color("Green-300"))
                    .foregroundColor(.black)
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
        }
        .padding()
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}
