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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // Resume from background — re-arm the session. The very first
                // activation is covered by AppDelegate's cold-launch events, so
                // only emit a resume event when coming back from background.
                if oldPhase == .background {
                    AnalyticsService.shared.startSession()
                    AnalyticsService.shared.trackEvent("app_foregrounded")
                    AnalyticsService.shared.trackEvent("session_started")
                }
            case .background:
                AnalyticsService.shared.trackEvent(
                    "app_backgrounded",
                    properties: ["session_duration_seconds": AnalyticsService.shared.currentSessionDuration]
                )
            default:
                break
            }
        }
    }
}
