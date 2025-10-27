//
//  mobileApp.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/13/25.
//

import SwiftUI

@main
struct mobileApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            FinishSignupView(
                phoneNumber: "123-456-7890",
                email: nil,
                password: nil,
                userId: "a1b2c3d4-e5f6-7890-1234-567890abcdef", // Example mock user ID
                path: .constant(NavigationPath())
            )
            .environmentObject(AuthViewModel())
        }
    }
}
