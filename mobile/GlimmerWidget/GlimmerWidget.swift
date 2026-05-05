import WidgetKit
import SwiftUI

// MARK: - Shared Colors & Helpers

private let neutral1000 = Color(red: 0.051, green: 0.051, blue: 0.051)

private func loadBundleImage(_ name: String) -> UIImage? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
          let data = try? Data(contentsOf: url),
          let img = UIImage(data: data)
    else { return nil }
    return img
}

// MARK: - Unified Provider

struct CombinedProvider: TimelineProvider {
    private func emptyShaker() -> WidgetShakerData {
        WidgetShakerData(emojis: [], isAllCompleted: false, lidColorStart: nil, lidColorEnd: nil, emojiPositions: nil)
    }
    func placeholder(in context: Context) -> CombinedEntry {
        let cats = WidgetDataStore.shared.loadTasks()
        let shaker = WidgetDataStore.shared.loadShaker() ?? emptyShaker()
        print("[ShakerWidget] placeholder family=\(context.family) emojis=\(shaker.emojis.count) allDone=\(shaker.isAllCompleted)")
        return CombinedEntry(date: Date(), categories: cats.isEmpty ? sampleCategories : cats, shaker: shaker)
    }
    func getSnapshot(in context: Context, completion: @escaping (CombinedEntry) -> Void) {
        let cats = WidgetDataStore.shared.loadTasks()
        let shaker = WidgetDataStore.shared.loadShaker() ?? emptyShaker()
        print("[ShakerWidget] getSnapshot family=\(context.family) isPreview=\(context.isPreview) emojis=\(shaker.emojis.count) allDone=\(shaker.isAllCompleted)")
        completion(CombinedEntry(
            date: Date(),
            categories: cats.isEmpty ? sampleCategories : cats,
            shaker: shaker
        ))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CombinedEntry>) -> Void) {
        let cats = WidgetDataStore.shared.loadTasks()
        let shaker = WidgetDataStore.shared.loadShaker() ?? emptyShaker()
        print("[ShakerWidget] getTimeline family=\(context.family) emojis=\(shaker.emojis.count) allDone=\(shaker.isAllCompleted) lid=\(shaker.lidColorStart ?? "nil")")
        let entry = CombinedEntry(date: Date(), categories: cats, shaker: shaker)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct CombinedEntry: TimelineEntry {
    let date: Date
    let categories: [WidgetCategoryTasks]
    let shaker: WidgetShakerData
}

// MARK: - Shared Subviews

/// Shaker jar view (uses raw PNG from bundle)
struct ShakerJarView: View {
    let shaker: WidgetShakerData
    let jarSize: CGFloat

    var body: some View {
        ZStack {
            if let jar = loadBundleImage("widgetJar") {
                Image(uiImage: jar)
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize, height: jarSize)
            }

            // Emojis inside jar
            let placements = computePlacements(count: shaker.emojis.count, jarSide: jarSize)
            ForEach(Array(zip(shaker.emojis.indices, shaker.emojis)), id: \.0) { index, emoji in
                if index < placements.count {
                    Text(emoji)
                        .font(.system(size: jarSize * 0.20))
                        .rotationEffect(.degrees(placements[index].rotation))
                        .offset(x: placements[index].x, y: placements[index].y)
                }
            }

            // Lid overlay
            if let lid = loadBundleImage("widgetLid") {
                Image(uiImage: lid)
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize, height: jarSize)
            }

            // Lid gradient on top with overlay blend to preserve lid texture
            if shaker.isAllCompleted,
               let c0 = Color(hex: shaker.lidColorStart),
               let c1 = Color(hex: shaker.lidColorEnd) {
                Rectangle()
                    .fill(LinearGradient(colors: [c0, c1], startPoint: .leading, endPoint: .trailing))
                    .frame(width: jarSize, height: jarSize * 0.17)
                    .cornerRadius(jarSize * 0.048)
                    .offset(y: -jarSize / 2 + jarSize * 0.087)
                    .blendMode(.overlay)
            }
        }
    }

    // MARK: - Hex-packed emoji placement

    private struct EmojiPlacement {
        let x: CGFloat
        let y: CGFloat
        let rotation: Double
    }

    private func computePlacements(count: Int, jarSide: CGFloat) -> [EmojiPlacement] {
        guard count > 0 else { return [] }

        let emojiR  = jarSide * 0.105
        let minDist = emojiR * 2.0
        let rowH    = minDist * 0.85

        let floorY   =  jarSide * 0.36
        let ceilingY = -jarSide * 0.28
        let wallX    =  jarSide * 0.33

        let maxPerRow = max(1, Int(floor(wallX * 2 / minDist)) + 1)

        let jitX: [CGFloat] = [0.020, -0.015, 0.025, -0.018, 0.010, -0.022, 0.016, -0.012, 0.023, -0.017]
        let jitY: [CGFloat] = [0.010, -0.015, 0.008, -0.012, 0.014, -0.006, 0.009, -0.013, 0.005, -0.011]
        let rots: [Double]  = [-18, 14, -8, 22, -14, 10, -25, 17, -6, 20]

        var result: [EmojiPlacement] = []
        var remaining = count
        var row = 0
        var idx = 0

        while remaining > 0 {
            let isOdd  = row % 2 == 1
            let nInRow = min(remaining, isOdd ? max(1, maxPerRow - 1) : maxPerRow)
            let rowWidth = CGFloat(nInRow - 1) * minDist
            let baseY = floorY - CGFloat(row) * rowH

            if baseY < ceilingY { break }

            for col in 0..<nInRow {
                let baseX = -rowWidth / 2 + CGFloat(col) * minDist
                let x = baseX + jitX[idx % jitX.count] * jarSide
                let y = baseY + jitY[idx % jitY.count] * jarSide
                result.append(EmojiPlacement(x: x, y: y, rotation: rots[idx % rots.count]))
                idx += 1
            }

            remaining -= nInRow
            row += 1
        }

        while result.count < count {
            let x = jitX[idx % jitX.count] * jarSide * 3
            result.append(EmojiPlacement(x: x, y: ceilingY, rotation: rots[idx % rots.count]))
            idx += 1
        }

        return result
    }
}

/// Shared header (clink logo + task count)
struct WidgetHeaderView: View {
    let categories: [WidgetCategoryTasks]
    var logoHeight: CGFloat = 12
    var countFontSize: CGFloat = 12

    private var allTasks: [WidgetTask] {
        categories.flatMap(\.tasks)
    }

    var body: some View {
        HStack {
            if let logo = loadBundleImage("widgetClink") {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: logoHeight)
                    .opacity(0.7)
            } else {
                Text("clink")
                    .font(.custom("Figtree-SemiBold", size: countFontSize + 1))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            let done = allTasks.filter(\.isCompleted).count
            Text("\(done)/\(allTasks.count)")
                .font(.custom("Figtree-Medium", size: countFontSize))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

/// Last updated timestamp
struct LastUpdatedView: View {
    let date: Date
    var compact: Bool = false
    var fontSize: CGFloat = 11

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    var body: some View {
        Text(compact ? "Last \(formattedTime)" : "Last updated \(formattedTime)")
            .font(.custom("Figtree-Regular", size: fontSize))
            .foregroundColor(.white.opacity(0.5))
    }
}

/// Task list view (reusable across widget sizes)
struct TaskListContentView: View {
    let categories: [WidgetCategoryTasks]
    let maxTasks: Int
    let date: Date
    var compactTimestamp: Bool = false
    var taskFontSize: CGFloat = 13
    var logoHeight: CGFloat = 12
    var headerFontSize: CGFloat = 12
    var footerFontSize: CGFloat = 11

    private var allTasks: [WidgetTask] {
        categories.flatMap(\.tasks)
    }

    var body: some View {
        if allTasks.isEmpty {
            VStack(spacing: 4) {
                Text("No tasks today")
                    .font(.custom("Figtree-Regular", size: taskFontSize))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                WidgetHeaderView(categories: categories, logoHeight: logoHeight, countFontSize: headerFontSize)
                    .padding(.bottom, 12)

                // Tasks
                let tasksToShow = collectTasks(max: maxTasks)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tasksToShow) { task in
                        HStack(spacing: 6) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: taskFontSize + 2))
                                .foregroundColor(task.isCompleted ? .green : .white.opacity(0.4))
                            Text(task.categoryEmoji)
                                .font(.system(size: taskFontSize + 1))
                            Text(task.title)
                                .font(.custom("Figtree-Regular", size: taskFontSize))
                                .strikethrough(task.isCompleted)
                                .foregroundColor(task.isCompleted ? .white.opacity(0.4) : .white)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Footer: +N more (left) and last updated (right)
                let remaining = allTasks.count - tasksToShow.count
                HStack {
                    if remaining > 0 {
                        Text("+\(remaining) more")
                            .font(.custom("Figtree-Regular", size: footerFontSize))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    LastUpdatedView(date: date, compact: compactTimestamp, fontSize: footerFontSize)
                }
                .padding(.top, 10)
            }
        }
    }

    private func collectTasks(max limit: Int) -> [WidgetTask] {
        var result: [WidgetTask] = []
        for category in categories {
            for task in category.tasks {
                if result.count >= limit { return result }
                result.append(task)
            }
        }
        return result
    }
}

// MARK: - 1. Small Task List Widget

struct SmallTaskListView: View {
    var entry: CombinedEntry
    var body: some View {
        ZStack {
            neutral1000.ignoresSafeArea()
            TaskListContentView(categories: entry.categories, maxTasks: 4, date: entry.date, compactTimestamp: true)
                .padding(18)
        }
    }
}

struct GlimmerTaskListWidget: Widget {
    let kind = "GlimmerTaskListWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CombinedProvider()) { entry in
            SmallTaskListView(entry: entry)
                .containerBackground(neutral1000, for: .widget)
        }
        .configurationDisplayName("Clink Tasks")
        .description("See your daily tasks.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - 2. Small Shaker Widget

struct SmallShakerOnlyView: View {
    var entry: CombinedEntry
    var body: some View {
        GeometryReader { geo in
            ZStack {
                neutral1000.ignoresSafeArea()
                let pad: CGFloat = 18
                let innerH = geo.size.height - pad * 2
                HStack(alignment: .top, spacing: 18) {
                    ShakerJarView(shaker: entry.shaker, jarSize: innerH)
                        .frame(width: innerH, height: innerH)
                }
                .padding(pad)
            }
        }
    }
}

struct GlimmerShakerWidget: Widget {
    let kind = "GlimmerShakerWidget67"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CombinedProvider()) { entry in
            SmallShakerOnlyView(entry: entry)
                .containerBackground(neutral1000, for: .widget)
        }
        .configurationDisplayName("Clink Shaker")
        .description("Your shaker jar.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - 3. Medium Combo Widget (shaker left, tasks right)

struct MediumComboView: View {
    var entry: CombinedEntry
    var body: some View {
        GeometryReader { geo in
            ZStack {
                neutral1000.ignoresSafeArea()
                let pad: CGFloat = 18
                let innerH = geo.size.height - pad * 2
                HStack(alignment: .top, spacing: 18) {
                    // Shaker fills the full inner height (square)
                    ShakerJarView(shaker: entry.shaker, jarSize: innerH)
                        .frame(width: innerH, height: innerH)

                    // Tasks fill remaining space (full height so header/footer pin to top/bottom)
                    TaskListContentView(categories: entry.categories, maxTasks: 3, date: entry.date, compactTimestamp: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(pad)
            }
        }
    }
}

struct GlimmerComboWidget: Widget {
    let kind = "GlimmerComboWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CombinedProvider()) { entry in
            MediumComboView(entry: entry)
                .containerBackground(neutral1000, for: .widget)
        }
        .configurationDisplayName("Clink Combo")
        .description("Shaker and tasks together.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - 4. Large Widget (shaker top, tasks below)

struct LargeFullView: View {
    var entry: CombinedEntry
    var body: some View {
        GeometryReader { geo in
            ZStack {
                neutral1000.ignoresSafeArea()
                VStack(spacing: 14) {
                    // Shaker on top
                    ShakerJarView(shaker: entry.shaker, jarSize: geo.size.width * 0.55)
                        .frame(height: geo.size.height * 0.5)

                    // Tasks below
                    TaskListContentView(categories: entry.categories, maxTasks: 3, date: entry.date, taskFontSize: 16, logoHeight: 15, headerFontSize: 13, footerFontSize: 13)
                }
                .padding(.horizontal, 20)
                .padding(.top, 25)
                .padding(.bottom, 17)
            }
        }
    }
}

struct GlimmerLargeWidget: Widget {
    let kind = "GlimmerLargeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CombinedProvider()) { entry in
            LargeFullView(entry: entry)
                .containerBackground(neutral1000, for: .widget)
        }
        .configurationDisplayName("Clink Full")
        .description("Shaker with your daily tasks.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Color Hex Helper

extension Color {
    init?(hex: String?) {
        guard let hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: ""),
              hex.count == 6,
              let val = UInt64(hex, radix: 16)
        else { return nil }
        self.init(
            red: Double((val >> 16) & 0xFF) / 255.0,
            green: Double((val >> 8) & 0xFF) / 255.0,
            blue: Double(val & 0xFF) / 255.0
        )
    }
}

// MARK: - Sample Data

private let sampleCategories: [WidgetCategoryTasks] = [
    WidgetCategoryTasks(id: UUID(), name: "Morning", emoji: "🌅", tasks: [
        WidgetTask(id: UUID(), title: "Meditate", isCompleted: true, categoryName: "Morning", categoryEmoji: "🌅"),
        WidgetTask(id: UUID(), title: "Workout", isCompleted: false, categoryName: "Morning", categoryEmoji: "🌅"),
    ]),
    WidgetCategoryTasks(id: UUID(), name: "Study", emoji: "📖", tasks: [
        WidgetTask(id: UUID(), title: "Read chapter 5", isCompleted: false, categoryName: "Study", categoryEmoji: "📖"),
    ]),
]

