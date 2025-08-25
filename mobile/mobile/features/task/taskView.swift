
import SwiftUI

struct TaskView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var sheetProgress: CGFloat = 0
    
    // --- date selection ---
    //@State private var today: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var showChangeDateSheet: Bool = false
    
    private var monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.setLocalizedDateFormatFromTemplate("MMMM d") // ex. July 2
        return f
    }()
    
    // --- options & sheet states ---
    @State private var showOptionsSheet: Bool = false
    
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
                        // Center: Date controls
                        HStack(spacing: 18) {

                            // 1) Previous day
                            Button {
                                if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDate = prev
                                    }
                                    viewModel.taskSelectedDate = prev
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color("Neutral-400"))
                            }
                            .buttonStyle(.plain)

                            // 2) Open calendar sheet (date text)
                            Button {
                                showChangeDateSheet = true
                            } label: {
                                Text(monthDayFormatter.string(from: selectedDate))
                                    .appFont(AppFont.title2)
                                    .foregroundColor(Color("White"))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            // 3) Next day
                            Button {
                                if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDate = next
                                    }
                                    viewModel.taskSelectedDate = next
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color("Neutral-400"))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Right: option button
                        HStack {
                            Spacer()
                            Button {
                                showOptionsSheet = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color("Neutral-800").opacity(0.35))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color("White"))
                                }
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 16)

                    // ---- Shaker (scaled) ----
                    ShakerView(viewModel: viewModel)
                        .frame(width: shakerSide, height: shakerSide)
                        .frame(maxWidth: 275)
                        .padding(.top, 16)
                }

                // ---- Bottom Sheet ----
                BottomSheet(
                    minHeight: 340,
                    maxHeight: 560,
                    progress: $sheetProgress
                ) {
                    // --Task List Content--
                    ScrollView {
                        TaskListView(taskSelectedDate: $selectedDate, viewModel: viewModel)
                            .padding(.bottom, 120)
                    }
                }
            }
            .animation(.easeInOut, value: scale)
            // --- "Options" sheet overlay ---
            .overlay(alignment: .bottomLeading) {
                if showOptionsSheet {
                    OptionsSheet(
                        onTapOutside: { showOptionsSheet = false },

                        onTapRoutines: { /* disabled; no-op */ },

                        onTapCategories: {
                            showOptionsSheet = false
                            showCategoriesSheet = true
                        },

                        onTapAddCategory: {
                            showOptionsSheet = false
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
            .animation(.easeInOut(duration: 0.25), value: showOptionsSheet)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            viewModel.fetchCategoriesAndTasks()
            viewModel.taskSelectedDate = selectedDate
        }
        .onChange(of: selectedDate) { newValue in
            viewModel.taskSelectedDate = newValue
            // viewModel.fetchCategoriesAndTasks()
        }
        // -- "Add category" sheet --
        .fullScreenCover(isPresented: $showAddCategorySheet) {
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
        .fullScreenCover(isPresented: $showCategoriesSheet) {
            CategoriesSheet(viewModel: viewModel)
        }
        // -- "Change Date" sheet --
        .overlay(alignment: .bottomLeading) {
            if showChangeDateSheet {
                ChangeDateSheet(
                    initialDate: selectedDate,
                    onConfirm: { picked in
                        selectedDate = picked
                        showChangeDateSheet = false
                    },
                    onCancel: {
                        showChangeDateSheet = false
                    }
                )
                .transition(.opacity)  // fade-in/out
                .ignoresSafeArea()
            }
        }
    }
}
//#Preview {TaskView()}
