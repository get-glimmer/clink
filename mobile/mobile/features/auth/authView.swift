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
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()
            VStack(spacing: 20) {
                Button("Sign In with Apple") {
                    saveUserId()
                    saveUserName()
                    isAuthenticated = true
                }
                .frame(height: 45)
                .buttonStyle(.borderedProminent)
                .foregroundColor(AppColors.textWhite)

                Button("Login (Email/Password)") {
                    saveUserId()
                    saveUserName()
                    isAuthenticated = true
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(AppColors.textWhite)
            }
            .padding()
        }
    }
}