
import SwiftUI

struct TaskView: View {
    @StateObject private var viewModel: TaskListViewModel
    init() {
        let userId = getUserId()
        _viewModel = StateObject(wrappedValue: TaskListViewModel(userId: userId))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Hi \(getUserName() ?? "User") 👋")
                    .font(.headline)
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.fetchCategoriesAndTasks()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.primary)
                            .imageScale(.small)
                            .frame(width: 20, height: 30)
                    }
                    .padding(.trailing)
                }
            }
            TaskListView(viewModel: viewModel)
        }
    }
}
