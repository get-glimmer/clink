//
//  authView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/18/25.
//

import SwiftUI

struct authView: View {
    @Binding var isAuthenticated: Bool
    var body: some View {
        VStack(spacing: 20) {
            Button("Login") {
                isAuthenticated = true
            }
            .buttonStyle(.borderedProminent)
            Button("Sign In") {
                isAuthenticated = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
