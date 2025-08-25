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
    
    var body: some View {
        VStack(spacing: 0) {
            // --- Header ---
            HStack {
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(Color("Neutral-800").opacity(0.35))
                            .frame(width: 44, height: 44)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                            .foregroundColor(Color("Neutral-400"))
                    }
                }
                Spacer()
                Text("Categories")
                    .appFont(AppFont.title2)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showAddCategorySheet = true }) {
                    ZStack {
                        Circle()
                            .fill(Color("Neutral-800").opacity(0.35))
                            .frame(width: 44, height: 44)
                        Image(systemName: "plus")
                            .font(.system(size: 16))
                            .foregroundColor(Color("Neutral-400"))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            
            // --- Category List ---
            List {
                // Daily
                Section(header:
                    Text("Daily Tasks")
                        .appFont(AppFont.labelS)
                        .foregroundColor(Color("Neutral-300"))
                ) {
                    ForEach(viewModel.categoriesWithTasks, id: \.id) { catWithTasks in
                        categoryRow(cat: catWithTasks.category)
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                let cat = viewModel.categoriesWithTasks[index].category
                                await viewModel.deleteCategory(categoryId: cat.id)
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        viewModel.moveCategories(from: indices, to: newOffset)
                    }
                }
                
                // Archived
                Section(header:
                    Text("Archived Tasks")
                        .appFont(AppFont.labelS)
                        .foregroundColor(Color("Neutral-300"))
                ) {
                    // TODO: archived categories
                }
            }
            .listStyle(.plain)
        }
        .fullScreenCover(isPresented: $showAddCategorySheet) {
            AddCategorySheet(
                emoji: .constant(""),
                name: .constant(""),
                isSaving: .constant(false),
                errorMessage: .constant(nil),
                onSave: { emoji, name, privacy in
                    Task {
                        try? await viewModel.addCategory(name: name, emoji: emoji, privacyStatus: privacy)
                        showAddCategorySheet = false
                    }
                }
            )
        }
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
    
    // MARK: - Category Row
    private func categoryRow(cat: CategoryItem) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(cat.emoji)
                    .appFont(AppFont.title1)
                Text(cat.name)
                    .appFont(AppFont.title3)
                    .foregroundColor(.white)
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
            // --- Divider ---
            Divider()
                .frame(width: 361)
                .background(Color("Neutral-800"))
                .opacity(0.5)
        }
        .padding(.vertical, 0)
    }
}
