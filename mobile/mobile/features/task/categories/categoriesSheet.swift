//
//  categoriesSheet.swift
//  mobile
//
//  Created by 이채린 on 8/20/25.
//
// categoriesSheet.swift
import SwiftUI

struct CategoriesSheet: View {
    @ObservedObject var viewModel: TaskListViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAddCategorySheet = false
    @State private var editingCategory: CategoryItem? = nil
    
    // AddCategorySheet States
    @State private var newCategoryEmoji: String = ""
    @State private var newCategoryName: String = ""
    @State private var isSavingCategory: Bool = false
    @State private var categorySaveError: String? = nil
    
    // Type filters
    private var dailyCategories: [CategoryWithTasks] {
        viewModel.categoriesWithTasks.filter { $0.category.type == .daily }
    }
    private var archivedCategories: [CategoryWithTasks] {
        viewModel.categoriesWithTasks.filter { $0.category.type == .archived }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- Header ---
            HStack {
                Button(action: { dismiss() }) {
                    Image("dismissButton")
                }
                Spacer()
                Text("Categories")
                    .appFont(AppFont.title2)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showAddCategorySheet = true }) {
                    Image("addButton")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
            
            // --- Category List ---
            List {
                // Daily
                Section(header:
                    Text("Daily Task")
                        .appFont(AppFont.labelS)
                        .foregroundColor(Color("Neutral-300"))
                        .padding(.leading, 4)
                ) {
                    ForEach(dailyCategories, id: \.id) { catWithTasks in
                        categoryRow(cat: catWithTasks.category)
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        Task {
                            for idx in indexSet {
                                let catId = dailyCategories[idx].category.id
                                await viewModel.deleteCategory(categoryId: catId)
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        viewModel.moveCategoriesWithinType(.daily, from: indices, to: newOffset)
                    }
                }
                
                // Archived
                Section(header:
                    Text("Archived Task")
                        .appFont(AppFont.labelS)
                        .foregroundColor(Color("Neutral-300"))
                        .padding(.leading, 4)
                ) {
                    ForEach(archivedCategories, id: \.id) { catWithTasks in
                        categoryRow(cat: catWithTasks.category)
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        Task {
                            for idx in indexSet {
                                let catId = archivedCategories[idx].category.id
                                await viewModel.deleteCategory(categoryId: catId)
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        viewModel.moveCategoriesWithinType(.archived, from: indices, to: newOffset)
                    }
                }
            }
            .listStyle(.plain)
        }
        .fullScreenCover(isPresented: $showAddCategorySheet) {
            AddCategorySheet(
                emoji: $newCategoryEmoji,
                name: $newCategoryName,
                isSaving: $isSavingCategory,
                errorMessage: $categorySaveError
            ) { emoji, name, privacy, type in
                isSavingCategory = true
                Task {
                    do {
                        try await viewModel.addCategory(
                            name: name,
                            emoji: emoji,
                            privacyStatus: privacy,
                            type: type
                        )
                        await MainActor.run {
                            isSavingCategory = false
                            showAddCategorySheet = false
                            newCategoryEmoji = ""
                            newCategoryName  = ""
                            categorySaveError = nil
                        }
                    } catch {
                        await MainActor.run {
                            isSavingCategory = false
                            categorySaveError = "Failed to save. Please try again."
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $editingCategory) { cat in
            EditCategorySheet(
                viewModel: viewModel,
                category: cat,
                onDone: { emoji, name, privacy, type in
                    Task {
                        await viewModel.updateCategory(
                            categoryId: cat.id,
                            name: name,
                            emoji: emoji,
                            privacyStatus: privacy,
                            type: type
                        )
                        editingCategory = nil
                    }
                },
                onDelete: {
                    Task {
                        await viewModel.deleteCategory(categoryId: cat.id)
                        editingCategory = nil
                    }
                }
            )
        }

    }
    
    // MARK: - Category Row
    private func categoryRow(cat: CategoryItem) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(viewModel.latestEmoji(for: cat.id, defaultEmoji: cat.emoji))
                    .font(.system(size: 27))
                Text(cat.name)
                    .appFont(AppFont.title3)
                    .foregroundColor(.white)
                    .padding(.leading, 1.42)
                Spacer()
                Button {
                    editingCategory = cat
                } label: {
                    Image("pencilGray")
                }
                .buttonStyle(.plain)
                
                Image("threeLines")
                    .padding(.leading, 12)
            }
            .padding(.horizontal, 4)
            // --- Divider ---
            Divider()
                .frame(width: 361)
                .background(Color("Neutral-800"))
                .opacity(0.5)
                .padding(.top, 6)
                .padding(.bottom, -8)
        }
        .padding(.vertical, 0)
    }
}
