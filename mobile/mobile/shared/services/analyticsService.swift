import Foundation
import UIKit
import Supabase
import FirebaseAnalytics

/// Central analytics entry point.
///
/// Routing rule (per spec #8):
///   - Pre-login events  -> Firebase only
///   - Post-login events -> Firebase + Supabase `public.user_events`
///
/// Never put PII, note bodies, or message contents in `properties`.
/// Only analytics-safe keys: source, button_location, category_id,
/// task_id, challenge_id, notification_type, etc.
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var supabase: SupabaseClient? {
        SupabaseClientManager.shared.client
    }

    /// New UUID per app launch — groups events into a single session.
    private let sessionId = UUID().uuidString

    /// Stable per-install id, persisted so pre-/post-login events can be stitched.
    private let anonymousId: String

    /// Last screen the user viewed, sent as `previous_screen`.
    private var previousScreen: String?

    /// Start time of the current foreground session, used to compute
    /// `session_duration_seconds` when the app is backgrounded.
    private var sessionStartedAt: Date = Date()

    private init() {
        let key = "analytics_anonymous_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            anonymousId = existing
        } else {
            let new = UUID().uuidString
            UserDefaults.standard.set(new, forKey: key)
            anonymousId = new
        }
    }

    // MARK: - Core

    /// Track an event to Firebase (always) and Supabase (only when logged in).
    /// - Parameters:
    ///   - eventName: snake_case event name, e.g. "task_completed"
    ///   - screenName: originating screen, e.g. "Home", "TaskDetail"
    ///   - source: high-level origin, e.g. "push", "deeplink", "button"
    ///   - properties: analytics-safe metadata only (no PII / content)
    func trackEvent(
        _ eventName: String,
        screenName: String? = nil,
        source: String? = nil,
        properties: [String: Any] = [:]
    ) {
        // 1) Firebase — fired for every event (pre- and post-login).
        var fbParams = properties
        if let screenName { fbParams["screen_name"] = screenName }
        if let source { fbParams["source"] = source }
        Analytics.logEvent(eventName, parameters: fbParams)

        // 2) Supabase — only when authenticated. Fire-and-forget.
        let prev = previousScreen
        Task {
            await insertUserEvent(
                eventName: eventName,
                screenName: screenName,
                previousScreen: prev,
                source: source,
                properties: properties
            )
        }
    }

    /// Convenience for button taps: fires a single canonical `button_tapped`
    /// event so all button usage lands in one queryable bucket. Identify the
    /// control with `buttonId` (e.g. "add_task_fab", "tab_community", "logout").
    func trackButtonTap(
        _ buttonId: String,
        screenName: String? = nil,
        properties: [String: Any] = [:]
    ) {
        var props = properties
        props["button_id"] = buttonId
        trackEvent("button_tapped", screenName: screenName, source: "button", properties: props)
    }

    // MARK: - Session lifecycle

    /// Marks the beginning of a foreground session. Call when the app enters the
    /// foreground (cold launch or resume) so session duration can be measured.
    func startSession() {
        sessionStartedAt = Date()
    }

    /// Seconds since the current session began.
    var currentSessionDuration: Int {
        Int(Date().timeIntervalSince(sessionStartedAt))
    }

    /// Convenience for screen entries: sends `screen_viewed` with the screen
    /// name and tracks `previous_screen` automatically.
    func trackScreen(_ screenName: String, properties: [String: Any] = [:]) {
        trackEvent("screen_viewed", screenName: screenName, properties: properties)
        previousScreen = screenName
    }

    /// Fires an event at most once per `dedupeKey` (default: the event name, i.e.
    /// once per install). Pass a composite key like "challenge_completed_<id>_<date>"
    /// to dedupe per-context instead. Backed by UserDefaults, so it resets on reinstall.
    func trackOnce(
        _ eventName: String,
        dedupeKey: String? = nil,
        screenName: String? = nil,
        source: String? = nil,
        properties: [String: Any] = [:]
    ) {
        let key = "analytics_once_\(dedupeKey ?? eventName)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        trackEvent(eventName, screenName: screenName, source: source, properties: properties)
    }

    // MARK: - Supabase insert

    private func insertUserEvent(
        eventName: String,
        screenName: String?,
        previousScreen: String?,
        source: String?,
        properties: [String: Any]
    ) async {
        guard let supabase else { return }

        // No session => pre-login event => Firebase-only, skip Supabase.
        // (To also log anonymous pre-login rows, drop this guard and send
        //  user_id = nil — anonymous_id/session_id still identify the row.)
        guard let session = try? await supabase.auth.session else { return }
        let userId = session.user.id.uuidString.lowercased()

        let row = UserEventRow(
            user_id: userId,
            anonymous_id: anonymousId,
            session_id: sessionId,
            event_name: eventName,
            event_properties: AnalyticsJSON(properties),
            screen_name: screenName,
            previous_screen: previousScreen,
            source: source,
            platform: "ios",
            app_version: Self.appVersion,
            device_model: Self.deviceModel,
            os_version: UIDevice.current.systemVersion
        )

        do {
            try await supabase.from("user_events").insert(row).execute()
        } catch {
            print("[Analytics] user_events insert failed: \(error)")
        }
    }

    // MARK: - Device metadata

    private static let appVersion: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

    private static let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let id = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return id.isEmpty ? UIDevice.current.model : id
    }()
}

private struct UserEventRow: Encodable {
    let user_id: String
    let anonymous_id: String
    let session_id: String
    let event_name: String
    let event_properties: AnalyticsJSON
    let screen_name: String?
    let previous_screen: String?
    let source: String?
    let platform: String
    let app_version: String
    let device_model: String
    let os_version: String
}

/// Minimal JSON wrapper so `[String: Any]` properties encode cleanly into a
/// Supabase jsonb column. Supports String / Bool / Int / Double / nested.
/// (Named to avoid colliding with Supabase's own public `AnyJSON` type.)
struct AnalyticsJSON: Encodable {
    private let value: Any
    init(_ value: Any) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as [String: Any]:
            try container.encode(v.mapValues { AnalyticsJSON($0) })
        case let v as [Any]:
            try container.encode(v.map { AnalyticsJSON($0) })
        case let v as String:
            try container.encode(v)
        case let v as Bool:
            try container.encode(v)
        case let v as Int:
            try container.encode(v)
        case let v as Double:
            try container.encode(v)
        default:
            try container.encodeNil()
        }
    }
}
