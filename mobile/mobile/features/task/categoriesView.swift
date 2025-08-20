//
//  categoriesView.swift
//  mobile
//
//  Created by 이채린 on 8/20/25.
//

import SwiftUI

struct CategoriesView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var editCategory: CategoryModel? = nil
    @State private var isEditSheetPresented = false
    
    init(viewModel: TaskListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
 
    var body: some View {
        NavigationStack {
            List {
                // Daily Tasks section
                Section(header: Text("Daily Tasks")) {
                    ForEach(viewModel.categories) { category in
                        HStack {
                            Text("\(category.emoji) \(category.name)")
                                .font(.body)
                            
                            Spacer()
                            
                            // Edit button
                            Button {
                                editCategory = category
                                isEditSheetPresented = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            // Drag handle -> modify order
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                        }
                    }
                    .onMove { indices, newOffset in
                        viewModel.moveCategory(from: indices, to: newOffset)
                    }
                }
                
                // Archived section
                Section(header: Text("Archived Tasks")) {
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $isEditSheetPresented) {
                if let category = editCategory {
                    EditCategorySheet(
                        category: category,
                        onSave: { updated in
                            viewModel.updateCategory(updated)
                            isEditSheetPresented = false
                        }
                    )
                }
            }
        }
    }
}
