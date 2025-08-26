//
//  chooseArchivedCategorySheet.swift
//  mobile
//
//  Created by 이채린 on 8/26/25.
//

import SwiftUI

struct ChooseArchivedCategorySheet: View {
    let archivedCategories: [CategoryItem]
    var onSelect: (CategoryItem) -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // --- Dimmed background (same as ChangeDateSheet) ---
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial).opacity(0.85)
                    .ignoresSafeArea()
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onCancel()
                dismiss()
            }

            // --- Card ---
            VStack(spacing: 10) {
                // Header
                HStack {
                    Text("Choose a Category")
                        .appFont(AppFont.title3)
                        .foregroundColor(Color("White"))
                    Spacer()
                    Button {
                        onCancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(Color("White"))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                .padding(.leading, 6)

                // Divider
                Divider()
                    .frame(width: 329)
                    .background(Color("Neutral-800"))

                // List (scrolls if content exceeds max height)
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(archivedCategories, id: \.id) { cat in
                            Button {
                                onSelect(cat)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(cat.emoji)
                                        .appFont(AppFont.title2)
                                    Text(cat.name)
                                        .appFont(AppFont.labelM)
                                        .foregroundColor(Color("White"))
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .frame(width: 329)
                                .background(Color("Neutral-800"))
                                .opacity(0.5)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }

                // bottom spacer to match ChangeDateSheet padding
                Spacer(minLength: 0)
                    .frame(height: 8)
            }
            .padding(16)
            .frame(width: 361, height: 481) // max height 481
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.black)).opacity(0.5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color("Neutral-400").opacity(0.7),
                                Color("Neutral-600").opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 14)
        }
    }
}
