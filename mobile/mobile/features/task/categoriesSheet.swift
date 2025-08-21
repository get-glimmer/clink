//
//  categoriesSheet.swift
//  mobile
//
//  Created by 이채린 on 8/20/25.
//
// categoriesSheet.swift

import SwiftUI

struct categoriesSheet: View {
    @ObservedObject var viewModel: TaskListViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Add Category sheet
    @State private var showAddCategorySheet: Bool = false
    @State private var newCategoryEmoji: String = ""
    @State private var newCategoryName: String = ""
    @State private var isSavingCategory: Bool = false
    @State private var categorySaveError: String? = nil
    
    // Edit Category sheet
    @State private var editingCategory: CategoryItem? = nil
    

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Categories")) {
                    ForEach(viewModel.categoriesWithTasks, id: \.id) { catWithTasks in
                        HStack {
                            Text(catWithTasks.category.emoji)
                            Text(catWithTasks.category.name)
                                .font(.headline)
                            Spacer()
                            Button {
                                editingCategory = catWithTasks.category
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(.gray)
                            }
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let category = viewModel.categoriesWithTasks[index].category
                            Task {
                                await viewModel.deleteCategory(categoryId: category.id)
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        viewModel.moveCategories(from: indices, to: newOffset)
                    }
                }

                Section(header: Text("Archived")) {
                    Text("Coming soon...")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        newCategoryEmoji = ""
                        newCategoryName = ""
                        showAddCategorySheet = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                    }
                }
            }
            // Add Category Sheet
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
            // Edit Category sheet
            .fullScreenCover(item: $editingCategory) { cat in
                EditCategorySheet(
                    category: cat,
                    onDone: { emoji, name, privacy in
                        Task {
                            await viewModel.updateCategory(
                                categoryId: cat.id,
                                name: name,
                                emoji: emoji,
                                privacyStatus: privacy
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
        .navigationViewStyle(StackNavigationViewStyle()) // for ipad
    }
}
