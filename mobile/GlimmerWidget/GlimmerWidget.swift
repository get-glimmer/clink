import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct TaskListProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskListEntry {
        TaskListEntry(date: Date(), categories: sampleCategories)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskListEntry) -> Void) {
        let categories = WidgetDataStore.shared.loadTasks()
        let entry = TaskListEntry(
            date: Date(),
            categories: categories.isEmpty ? sampleCategories : categories
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskListEntry>) -> Void) {
        let categories = WidgetDataStore.shared.loadTasks()
        let totalTasks = categories.flatMap(\.tasks).count
        print("[GlimmerWidget] getTimeline: \(categories.count) categories, \(totalTasks) tasks")
        let entry = TaskListEntry(date: Date(), categories: categories)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct TaskListEntry: TimelineEntry {
    let date: Date
    let categories: [WidgetCategoryTasks]
}

// MARK: - Widget Views

struct TaskListWidgetEntryView: View {
    var entry: TaskListEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if entry.categories.isEmpty || allTasks.isEmpty {
            emptyView
        } else {
            taskListContent
        }
    }

    private var allTasks: [WidgetTask] {
        entry.categories.flatMap { $0.tasks }
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Text("clink")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No tasks today")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
    }

    private var taskListContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.bottom, 8)

            let maxTasks = maxVisibleTasks
            let tasksToShow = collectTasks(max: maxTasks)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(tasksToShow) { task in
                    taskRow(task)
                }
            }

            let totalCount = allTasks.count
            let remaining = totalCount - tasksToShow.count
            if remaining > 0 {
                Text("+\(remaining) more")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
    }

    private var headerView: some View {
        HStack {
            Text("clink")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            let tasks = allTasks
            let done = tasks.filter(\.isCompleted).count
            Text("\(done)/\(tasks.count)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func taskRow(_ task: WidgetTask) -> some View {
        HStack(spacing: 6) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundStyle(task.isCompleted ? .green : .secondary)

            Text(task.categoryEmoji)
                .font(.system(size: 11))

            Text(task.title)
                .font(.system(size: 13))
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .lineLimit(1)
        }
    }

    private var maxVisibleTasks: Int {
        switch family {
        case .systemSmall: return 4
        case .systemMedium: return 5
        case .systemLarge: return 12
        default: return 4
        }
    }

    private func collectTasks(max limit: Int) -> [WidgetTask] {
        var result: [WidgetTask] = []
        for category in entry.categories {
            for task in category.tasks {
                if result.count >= limit { return result }
                result.append(task)
            }
        }
        return result
    }
}

// MARK: - Widget Definition

struct GlimmerTaskListWidget: Widget {
    let kind: String = "GlimmerTaskListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskListProvider()) { entry in
            TaskListWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Glimmer Tasks")
        .description("See your daily tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Sample Data

private let sampleCategories: [WidgetCategoryTasks] = [
    WidgetCategoryTasks(
        id: UUID(),
        name: "Morning",
        emoji: "🌅",
        tasks: [
            WidgetTask(id: UUID(), title: "Meditate", isCompleted: true, categoryName: "Morning", categoryEmoji: "🌅"),
            WidgetTask(id: UUID(), title: "Workout", isCompleted: false, categoryName: "Morning", categoryEmoji: "🌅"),
        ]
    ),
    WidgetCategoryTasks(
        id: UUID(),
        name: "Study",
        emoji: "📖",
        tasks: [
            WidgetTask(id: UUID(), title: "Read chapter 5", isCompleted: false, categoryName: "Study", categoryEmoji: "📖"),
        ]
    ),
]

#Preview(as: .systemSmall) {
    GlimmerTaskListWidget()
} timeline: {
    TaskListEntry(date: .now, categories: sampleCategories)
}

#Preview(as: .systemMedium) {
    GlimmerTaskListWidget()
} timeline: {
    TaskListEntry(date: .now, categories: sampleCategories)
}
