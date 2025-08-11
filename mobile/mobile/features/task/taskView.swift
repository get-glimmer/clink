
import SwiftUI

struct TaskView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var sheetProgress: CGFloat = 0
    
    // on a TaskView, "today" which is accepted as a parameter will not be changed as the
    // page only shows today's tasks.
    @State private var today: Date = Date()

    init() {
        let userId = getUserId()
        _viewModel = StateObject(wrappedValue: TaskListViewModel(userId: userId, date: todayDate()))
    }


    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width*0.9
            let scale = max(0.4, 1 - 0.6 * sheetProgress)
            let shakerSide = fullWidth * scale

            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    // ---- Header ----
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
                    .padding(.top, 16)

                    // ---- Shaker (scaled) ----
                    ShakerView(viewModel: viewModel)
                        .frame(width: shakerSide, height: shakerSide)
                        .padding(.top, 24)
                }
                .frame(maxWidth: 270, alignment: .top)

                // ---- Bottom Sheet ----
                BottomSheet(
                    minHeight: 340,
                    maxHeight: 560,
                    progress: $sheetProgress
                ) {
                    // --Task List Content--
                    ScrollView {
                        TaskListView(taskSelectedDate: $today, viewModel: viewModel)
                            .padding(.horizontal)
                            .padding(.bottom, 120)
                    }
                }
            }
            .animation(.easeInOut, value: scale)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            viewModel.fetchCategoriesAndTasks()
            animateSheetBounce()
        }
    }
    private func animateSheetBounce() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            sheetProgress = 0.001
        }
        // bottom-sheet collapses in 0.4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                sheetProgress = 0
            }
        }
    }
}
#Preview {TaskView()}
