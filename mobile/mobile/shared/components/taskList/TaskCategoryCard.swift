import SwiftUI

// Reusable category card used by multiple screens
// - Supports readOnly rendering for friend view
// - Accepts a trailing accessory (e.g., plus button, heart button)
struct TaskCategoryCard<Accessory: View>: View {
    let categoryWithTasks: CategoryWithTasks
    let backgroundColor: Color
    let readOnly: Bool
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .foregroundColor(backgroundColor)

            VStack(alignment: .leading, spacing: 25) {
                header
                tasks
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: categoryWithTasks.tasks.isEmpty ? 60 : 120)
        .padding(.vertical, 8)
    }

    private var header: some View {
        HStack {
            Text(categoryWithTasks.category.emoji)
                .font(.system(size: 24))

            Text(categoryWithTasks.category.name)
                .appFont(AppFont.title3)
                .foregroundColor(AppColors.textWhite)
                .padding(.leading, 1.42)

            Spacer()
            accessory()
        }
    }

    private var tasks: some View {
        VStack(alignment: .leading, spacing: 25) {
            ForEach(categoryWithTasks.tasks) { task in
                HStack(spacing: 12) {
                    checkbox(for: task)
                    Text(task.title)
                        .appFont(AppFont.body1)
                        .foregroundColor(AppColors.textWhite)
                        .strikethrough(task.isCompleted)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func checkbox(for task: TaskListItem) -> some View {
        if readOnly {
            Image(task.isCompleted ? "checkboxFilled" : "checkboxEmpty")
                .foregroundColor(AppColors.textWhite)
        } else {
            Image(task.isCompleted ? "checkboxFilled" : "checkboxEmpty")
                .foregroundColor(AppColors.textWhite)
        }
    }
}


