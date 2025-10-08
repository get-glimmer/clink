//
//  chooseDailyCategorySheet.swift
//  mobile
//
//  Created by Kristie Lee on 10/8/25.
//

import SwiftUI

/// Choose one of Daily-type categories (UI is same as ChooseArchivedCategorySheet)
struct ChooseDailyCategorySheet: View {
    let dailyCategories: [CategoryItem]
    var onSelect: (CategoryItem) -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Dimmed BG
            ZStack {
                Rectangle().fill(.ultraThinMaterial).opacity(0.85).ignoresSafeArea()
                Color.black.opacity(0.8).ignoresSafeArea()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onCancel()
                dismiss()
            }

            // Card
            VStack(spacing: 10) {
                // Header
                HStack {
                    Text("Choose a Daily Category")
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

                Divider()
                    .frame(width: 329)
                    .background(Color("Neutral-800"))

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(dailyCategories, id: \.id) { cat in
                            Button {
                                onSelect(cat)
                                dismiss()
                            } label: {
                                HStack(spacing: 28) {
                                    ZStack {
                                        Circle()
                                            .fill(Color("Neutral-800"))
                                            .frame(width: 44, height: 44)
                                        Text(cat.emoji).font(.system(size: 26))
                                    }
                                    Text(cat.name)
                                        .appFont(AppFont.labelM)
                                        .foregroundColor(Color("White"))
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }

                Spacer(minLength: 0).frame(height: 8)
            }
            .padding(16)
            .frame(width: 361, height: 321)
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
                            colors: [Color("Neutral-400").opacity(0.7), Color("Neutral-600").opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 14)
        }
    }
}
