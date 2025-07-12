//
//  authView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/18/25.
//

import SwiftUI

struct AuthView: View {
    @Binding var isAuthenticated: Bool

    var body: some View {
        VStack(spacing: 20) {
            Button("Sign In with Apple") {
                saveUserId()
                saveUserName()
                isAuthenticated = true
            }
            .frame(height: 45)
            .buttonStyle(.borderedProminent)

            Button("Login (Email/Password)") {
                saveUserId()
                saveUserName()
                isAuthenticated = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// Preview
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView(isAuthenticated: .constant(false))
    }
}
