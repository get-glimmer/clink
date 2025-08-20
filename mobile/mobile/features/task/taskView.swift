
import SwiftUI

struct TaskView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var sheetProgress: CGFloat = 0
    
    // on a TaskView, "today" which is accepted as a parameter will not be changed as the
    // page only shows today's tasks.
    @State private var today: Date = Date()
    
    // --- options & sheet states ---
    @State private var showOptionsOverlay: Bool = false
    
    // 1. Add Category
    @State private var showAddCategorySheet: Bool = false
    @State private var newCategoryEmoji: String = ""
    @State private var newCategoryName: String = ""
    @State private var isSavingCategory: Bool = false
    @State private var categorySaveError: String? = nil
    
    // 2. Categories
    @State private var showCategoriesSheet: Bool = false

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
                            Button {
                                showOptionsOverlay = true
                            } label: {
                                Image(systemName: "ellipsis")
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
            // Options overlay
            .overlay(alignment: .bottomLeading) {
                if showOptionsOverlay {
                    OptionsOverlay(
                        onTapOutside: { showOptionsOverlay = false },

                        onTapRoutines: { /* disabled; no-op */ },

                        onTapCategories: {
                            showOptionsOverlay = false
                            showCategoriesSheet = true
                        },

                        onTapAddCategory: {
                            showOptionsOverlay = false
                            // Reset inputs and open AddCategorySheet
                            newCategoryEmoji = ""
                            newCategoryName = ""
                            showAddCategorySheet = true
                        }
                    )
                    .transition(.opacity)
                    .ignoresSafeArea()
                }
            }
            .zIndex(999)
            .animation(.easeInOut(duration: 0.25), value: showOptionsOverlay)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            viewModel.fetchCategoriesAndTasks()
            //animateSheetBounce()
        }
        // -- "Add category" sheet --
        .sheet(isPresented: $showAddCategorySheet) {
            AddCategorySheet(
                emoji: $newCategoryEmoji,
                name: $newCategoryName,
                isSaving: $isSavingCategory,
                errorMessage: $categorySaveError,
                onSave: { emoji, name, privacy in
                    isSavingCategory = true
                    Task {
                        do {
                            try await viewModel.addCategory(name: name, emoji: emoji, privacyStatus: privacy)
                            isSavingCategory = false
                            showAddCategorySheet = false
                        } catch {
                            isSavingCategory = false
                            categorySaveError = "Failed to add the category. Please try again."
                        }
                    }
                }
            )
        }
        // -- "Categories" sheet --
        .sheet(isPresented: $showCategoriesSheet) {
            CategoriesView(viewModel: viewModel)
        }
    }
}
#Preview {TaskView()}
