//
//  GlimmerWidget.swift
//  GlimmerWidget
//
//  Created by Soohyeuk Choi on 3/7/26.
//

import WidgetKit
import SwiftUI

// MARK: - Data Model

struct ShakerData {
    let emojis: [String]
    let progress: Double // 0.0 - 1.0
    let lidColorStart: Color?
    let lidColorEnd: Color?
    
    var isCompleted: Bool {
        progress >= 1.0 && lidColorStart != nil && lidColorEnd != nil
    }
    
    static let placeholder = ShakerData(
        emojis: ["📚", "💪", "🎨"],
        progress: 0.6,
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

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ShakerEntry {
        ShakerEntry(date: Date(), shakerData: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShakerEntry) -> Void) {
        let entry = ShakerEntry(date: Date(), shakerData: .sampleIncomplete)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShakerEntry>) -> Void) {
        // For now, use sample data - later this will read from App Group shared data
        let currentDate = Date()
        let shakerData = ShakerData.sampleIncomplete
        
        let entry = ShakerEntry(date: currentDate, shakerData: shakerData)
        
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

struct ShakerEntry: TimelineEntry {
    let date: Date
    let shakerData: ShakerData
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
            // Jar body (simple shape fallback for now)
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
        // Scale emoji size based on jar size
        min(jarSize.width, jarSize.height) * 0.15
    }
    
    private func calculateEmojiPositions() -> [CGPoint] {
        // Position emojis near the bottom of the jar in a scattered pattern
        let inset: CGFloat = jarSize.width * 0.15
        let bottomY = jarSize.height * 0.75
        let rowHeight = emojiSize * 0.8
        
        var positions: [CGPoint] = []
        let maxPerRow = 3
        
        for (index, _) in emojis.enumerated() {
            let row = index / maxPerRow
            let col = index % maxPerRow
            
            // Calculate base X position with some randomness
            let totalWidth = jarSize.width - (inset * 2)
            let spacing = totalWidth / CGFloat(min(emojis.count, maxPerRow))
            let baseX = inset + spacing * (CGFloat(col) + 0.5)
            
            // Add slight offset for natural look
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

    var body: some View {
        WidgetShakerView(shakerData: entry.shakerData, size: CGSize(width: jarSize, height: jarSize))
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
