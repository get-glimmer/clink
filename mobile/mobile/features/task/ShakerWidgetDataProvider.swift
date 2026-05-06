//
//  ShakerWidgetDataProvider.swift
//  mobile
//
//  Shared data bridge between the main app and the GlimmerWidget extension.
//  Both targets must belong to the same App Group.
//

import Foundation
import SwiftUI

// MARK: - App Group identifier
// Add this App Group to BOTH the main app target and the widget extension target in Xcode:
//   Signing & Capabilities → + Capability → App Groups → group.com.glimmer.shared
let appGroupIdentifier = "group.com.glimmer.shared"

// MARK: - Codable widget payload

/// Lightweight snapshot of the shaker state, written by the main app
/// and read by the widget extension.
struct ShakerWidgetPayload: Codable {
    let emojis: [String]            // category emojis for completed tasks
    let totalTasks: Int             // total daily tasks
    let completedTasks: Int         // completed daily tasks
    let lidColorStartHex: String?   // hex string, e.g. "#4ACC99"
    let lidColorEndHex: String?
    let lastUpdated: Date

    var progress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    var isCompleted: Bool {
        progress >= 1.0 && lidColorStartHex != nil && lidColorEndHex != nil
    }

    static let empty = ShakerWidgetPayload(
        emojis: [],
        totalTasks: 0,
        completedTasks: 0,
        lidColorStartHex: nil,
        lidColorEndHex: nil,
        lastUpdated: Date()
    )
}

// MARK: - Provider (main app writes, widget reads)

enum ShakerWidgetDataProvider {

    private static let key = "shakerWidgetData"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: Write (called from main app)

    static func write(_ payload: ShakerWidgetPayload) {
        guard let defaults = sharedDefaults else {
            return
        }
        do {
            let data = try JSONEncoder().encode(payload)
            defaults.set(data, forKey: key)
        } catch {
        }
    }

    // MARK: Read (called from widget extension)

    static func read() -> ShakerWidgetPayload {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: key) else {
            return .empty
        }
        do {
            return try JSONDecoder().decode(ShakerWidgetPayload.self, from: data)
        } catch {
            return .empty
        }
    }
}
