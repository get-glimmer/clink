
import SwiftUI

struct TaskView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var sheetProgress: CGFloat = 0

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
                    HStack {
                        Spacer()
                        Text("Hi \(getUserName() ?? "User") 👋")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .padding(.trailing)
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
                        TaskListView(viewModel: viewModel)
                            .padding(.horizontal)
                            .padding(.bottom, 120)
                    }
                }
            }
            .animation(.easeInOut, value: scale)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
#Preview {TaskView()}
