
import SwiftUI

struct TaskView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var shakerScale: CGFloat = 1.0    // For future bottom-sheet shrink effect

    init() {
        let userId = getUserId()
        _viewModel = StateObject(wrappedValue: TaskListViewModel(userId: userId, date: todayDate()))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text("Hi \(getUserName() ?? "User") 👋")
                    .font(.headline)
                HStack {
                    Spacer()
                    Button(action: { viewModel.fetchCategoriesAndTasks() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.primary)
                            .imageScale(.small)
                            .frame(width: 20, height: 30)
                    }
                    .padding(.trailing)
                }
            }
            .padding(.bottom, 8)

            // Digital Shaker
            ShakerView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)   // jar fills 95% width
                .scaleEffect(shakerScale)
                .animation(.easeInOut, value: shakerScale)

            // Task list
            TaskListView(viewModel: viewModel)
                .padding(.top, 8)
        }
        .padding(.horizontal)
    }
}
#Preview {TaskView()}
