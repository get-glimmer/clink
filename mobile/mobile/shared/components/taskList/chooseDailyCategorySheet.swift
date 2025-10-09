//
//  chooseDailyCategorySheet.swift
//  mobile
//
//  Created by Kristie Lee on 10/8/25.
//

import SwiftUI

struct ChooseDailyCategorySheet: View {
    let dailyCategories: [CategoryItem]
    var onSelect: (CategoryItem) -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    
    // Layout constants
    private let baseHeight: CGFloat = 173
    private let itemHeight: CGFloat = 64      // Height per category row
    
    // Dynamic card height
    private var cardHeight: CGFloat {
        let count = dailyCategories.count
        switch count {
        case 0, 1:
            return baseHeight
        case 2:
            return baseHeight + itemHeight * 1
        case 3:
            return baseHeight + itemHeight * 2
        case 4:
            return baseHeight + itemHeight * 3
        default:
            return baseHeight + itemHeight * 4
        }
    }

    var body: some View {
        ZStack {
            // --- Dimmed background ---
            ZStack {
                DarkBlurView(style: .systemChromeMaterialDark)
                    .ignoresSafeArea()

                Color.black.opacity(0.5)
                    .ignoresSafeArea()

            }
            .contentShape(Rectangle())
            .onTapGesture {
                onCancel()
                dismiss()
            }

            // Card
            VStack(spacing:0){
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
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 21)
                .padding(.bottom, 18)
                .padding(.leading, 25)
                .padding(.trailing, 23)

                Divider()
                    .frame(width: 329)
                    .background(Color("Neutral-800"))

                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(dailyCategories, id: \.id) { cat in
                            Button {
                                onSelect(cat)
                                dismiss()
                            } label: {
                                HStack(spacing: 0) {
                                    ZStack {
                                        Circle()
                                            .fill(.neutral800)
                                            .frame(width: 44, height: 44)
                                        Text(cat.emoji).font(.system(size: 26))
                                            .padding(.leading,2)
                                    }
                                    Text(cat.name)
                                        .appFont(AppFont.labelM)
                                        .foregroundColor(Color("White"))
                                        .padding(.leading,16)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 30)
                }
            }
            .frame(width: 361, height: cardHeight)
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
                            colors: [Color(.neutral400).opacity(0.7), Color(.neutral600).opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
}
