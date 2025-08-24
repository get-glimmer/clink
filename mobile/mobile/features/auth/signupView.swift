import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Sign Up")
                .font(.largeTitle)
                .bold()

            TextField("Email", text: $email)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Sign Up") {
                Task { await signup() }
            }
            .buttonStyle(.borderedProminent)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    func signup() async {
        do {
            guard let client = SupabaseClientManager.shared.client else { return }
            _ = try await client.auth.signUp(email: email, password: password)
            
            // Set auth state in AuthViewModel
            authViewModel.email = email
            authViewModel.isAuthenticated = true
            
            // Optionally load profile immediately
            await authViewModel.loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
