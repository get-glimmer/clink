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
            //RootView()
            shakerView()
        }
    }
}


