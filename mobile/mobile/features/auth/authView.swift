//
//  authView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/18/25.
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Binding var isAuthenticated: Bool

    var body: some View {
        VStack(spacing: 20) {
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    viewModel.signInWithApple()
                },
                onCompletion: { result in
                    // Handled in ViewModel
                }
            )
            .frame(height: 45)
            .signInWithAppleButtonStyle(.black)

            Button("Login (Email/Password)") {
                // Example: you would present a login form and call viewModel.login(email:password:)
            }
            .buttonStyle(.borderedProminent)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .onReceive(viewModel.$isAuthenticated) { value in
            isAuthenticated = value
        }
    }
}

// Preview
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView(viewModel: AuthViewModel(), isAuthenticated: .constant(false))
    }
}
