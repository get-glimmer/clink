//
//  GlimmerWidget.swift
//  GlimmerWidget
//
//  Created by Soohyeuk Choi on 3/7/26.
//

import WidgetKit
import SwiftUI

// MARK: - App Group (must match main app)

private let widgetAppGroupId = "group.com.glimmer.shared"
private let widgetDataKey = "shakerWidgetData"

// MARK: - Codable payload (mirrors ShakerWidgetPayload in the main app)

struct WidgetShakerPayload: Codable {
    let emojis: [String]
    let totalTasks: Int
    let completedTasks: Int
    let lidColorStartHex: String?
    let lidColorEndHex: String?
    let lastUpdated: Date

    var progress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    var isCompleted: Bool {
        progress >= 1.0 && lidColorStartHex != nil && lidColorEndHex != nil
    }

    static let empty = WidgetShakerPayload(
        emojis: [],
        totalTasks: 0,
        completedTasks: 0,
        lidColorStartHex: nil,
        lidColorEndHex: nil,
        lastUpdated: Date()
    )
}

// MARK: - Data Model (view-level)

struct ShakerData {
    let emojis: [String]
    let progress: Double // 0.0 - 1.0
    let lidColorStart: Color?
    let lidColorEnd: Color?

    var isCompleted: Bool {
        progress >= 1.0 && lidColorStart != nil && lidColorEnd != nil
    }

    /// Build from the shared payload written by the main app.
    static func fromPayload(_ p: WidgetShakerPayload) -> ShakerData {
        ShakerData(
            emojis: p.emojis,
            progress: p.progress,
            lidColorStart: Color(hex: p.lidColorStartHex),
            lidColorEnd: Color(hex: p.lidColorEndHex)
        )
    }

    static let placeholder = ShakerData(
        emojis: [],
        progress: 0,
        lidColorStart: nil,
        lidColorEnd: nil
    )

    static let sampleIncomplete = ShakerData(
        emojis: ["📚", "💪", "🎨", "🎵"],
        progress: 0.5,
        lidColorStart: nil,
        lidColorEnd: nil
    )

    static let sampleComplete = ShakerData(
        emojis: ["📚", "💪", "🎨", "🎵", "🧘"],
        progress: 1.0,
        lidColorStart: Color(red: 0.4, green: 0.8, blue: 0.6),
        lidColorEnd: Color(red: 0.2, green: 0.6, blue: 0.9)
    )
}

// MARK: - Color hex init (widget-side, no UIKit dependency)

private extension Color {
    init?(hex: String?) {
        guard let hex = hex else { return nil }
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let v = Int(str, radix: 16) else { return nil }
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >>  8) & 0xFF) / 255,
            blue:  Double( v        & 0xFF) / 255
        )
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ShakerEntry {
        ShakerEntry(date: Date(), shakerData: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShakerEntry) -> Void) {
        let (data, updated) = readSharedDataWithDate()
        let entry = ShakerEntry(date: Date(), shakerData: data, lastUpdated: updated)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShakerEntry>) -> Void) {
        let currentDate = Date()
        let (shakerData, updated) = readSharedDataWithDate()
        let entry = ShakerEntry(date: currentDate, shakerData: shakerData, lastUpdated: updated)

        // Refresh every 15 minutes as a fallback; main app also triggers reloads on changes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    /// Read the shaker payload from App Group shared UserDefaults.
    private func readSharedDataWithDate() -> (ShakerData, Date?) {
        guard let defaults = UserDefaults(suiteName: widgetAppGroupId) else {
            print("🔴 [Widget] App Group UserDefaults is nil – is '\(widgetAppGroupId)' added to BOTH targets?")
            return (.placeholder, nil)
        }

        guard let data = defaults.data(forKey: widgetDataKey) else {
            print("🔴 [Widget] No data found for key '\(widgetDataKey)' – main app hasn't written yet")
            return (.placeholder, nil)
        }

        do {
            let payload = try JSONDecoder().decode(WidgetShakerPayload.self, from: data)
            print("🟢 [Widget] Read payload: emojis=\(payload.emojis), progress=\(payload.progress), completed=\(payload.isCompleted), lastUpdated=\(payload.lastUpdated)")

            if !Calendar.current.isDateInToday(payload.lastUpdated) {
                print("🟡 [Widget] Data is stale (from \(payload.lastUpdated)), showing empty jar")
                return (ShakerData(emojis: [], progress: 0, lidColorStart: nil, lidColorEnd: nil), payload.lastUpdated)
            }

            return (ShakerData.fromPayload(payload), payload.lastUpdated)
        } catch {
            print("🔴 [Widget] Decode failed: \(error)")
            return (.placeholder, nil)
        }
    }
}

struct ShakerEntry: TimelineEntry {
    let date: Date
    let shakerData: ShakerData
    var lastUpdated: Date? = nil
}

// MARK: - Static Shaker View (Widget-safe, no SpriteKit)

struct WidgetShakerView: View {
    let shakerData: ShakerData
    let size: CGSize

    // Lid visual ratios (matching main app)
    private let lidHeightRatio: CGFloat = 46.0 / 270.0
    private let lidCornerRatio: CGFloat = 13.0 / 270.0
    private let lidTopInsetRatio: CGFloat = 23.5 / 270.0

    var body: some View {
        let jarSize = size

        ZStack {
            // Jar body
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.2))
                .frame(width: jarSize.width * 0.85, height: jarSize.height * 0.75)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                )
                .offset(y: jarSize.height * 0.05)

            // Lid (top part)
            RoundedRectangle(cornerRadius: 8)
                .fill(shakerData.isCompleted ?
                      AnyShapeStyle(LinearGradient(
                        colors: [shakerData.lidColorStart ?? .gray, shakerData.lidColorEnd ?? .gray],
                        startPoint: .leading,
                        endPoint: .trailing
                      )) :
                      AnyShapeStyle(Color.gray.opacity(0.4)))
                .frame(width: jarSize.width * 0.85, height: jarSize.height * lidHeightRatio)
                .offset(y: -jarSize.height * 0.35)

            // Static emoji display at bottom of jar
            StaticEmojiLayer(emojis: shakerData.emojis, jarSize: jarSize)
        }
        .frame(width: jarSize.width, height: jarSize.height)
    }
}

// MARK: - Static Emoji Layer

struct StaticEmojiLayer: View {
    let emojis: [String]
    let jarSize: CGSize

    var body: some View {
        let positions = calculateEmojiPositions()

        ZStack {
            ForEach(Array(emojis.enumerated()), id: \.offset) { index, emoji in
                if index < positions.count {
                    Text(emoji)
                        .font(.system(size: emojiSize))
                        .position(positions[index])
                }
            }
        }
        .frame(width: jarSize.width, height: jarSize.height)
    }

    private var emojiSize: CGFloat {
        min(jarSize.width, jarSize.height) * 0.15
    }

    private func calculateEmojiPositions() -> [CGPoint] {
        let inset: CGFloat = jarSize.width * 0.15
        let bottomY = jarSize.height * 0.75
        let rowHeight = emojiSize * 0.8

        var positions: [CGPoint] = []
        let maxPerRow = 3

        for (index, _) in emojis.enumerated() {
            let row = index / maxPerRow
            let col = index % maxPerRow

            let totalWidth = jarSize.width - (inset * 2)
            let spacing = totalWidth / CGFloat(min(emojis.count, maxPerRow))
            let baseX = inset + spacing * (CGFloat(col) + 0.5)

            let xOffset = CGFloat(index % 2 == 0 ? 5 : -5)
            let yOffset = CGFloat(index % 3) * 3

            let x = baseX + xOffset
            let y = bottomY - CGFloat(row) * rowHeight + yOffset

            positions.append(CGPoint(x: x, y: y))
        }

        return positions
    }
}

// MARK: - Widget Entry View

struct GlimmerWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) var family

    private var jarSize: CGFloat {
        switch family {
        case .systemSmall:
            return 120
        case .systemMedium:
            return 130
        default:
            return 120
        }
    }

    private var lastUpdatedText: String {
        guard let date = entry.lastUpdated else { return "No data yet" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return "Updated \(formatter.string(from: date))"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WidgetShakerView(shakerData: entry.shakerData, size: CGSize(width: jarSize, height: jarSize))
            Text(lastUpdatedText)
                .font(.system(size: 8))
                .foregroundColor(.gray)
                .padding(6)
        }
    }
}

// MARK: - Widget Configuration

struct GlimmerWidget: Widget {
    let kind: String = "GlimmerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GlimmerWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Glimmer Shaker")
        .description("See your daily task progress in a shaker jar.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    GlimmerWidget()
} timeline: {
    ShakerEntry(date: .now, shakerData: .sampleIncomplete)
    ShakerEntry(date: .now, shakerData: .sampleComplete)
}

#Preview(as: .systemMedium) {
    GlimmerWidget()
} timeline: {
    ShakerEntry(date: .now, shakerData: .sampleComplete)
}
