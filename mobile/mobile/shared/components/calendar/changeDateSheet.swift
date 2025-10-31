//
//  changeDateSheet.swift
//  mobile
//
//  Created by 이채린 on 8/24/25.
//

import SwiftUI

public struct ChangeDateSheet: View {
    public let initialDate: Date
    public var onConfirm: (Date) -> Void
    public var onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var pickedDate: Date
    
    // MARK: - Init
    public init(
        initialDate: Date,
        onConfirm: @escaping (Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialDate = initialDate
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _pickedDate = State(initialValue: initialDate)
    }
    
    // MARK: - Body
    public var body: some View {
        ZStack {
            ZStack {
                DarkBlurView(style: .systemChromeMaterialDark)
                    .ignoresSafeArea()
                
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
            }
            .contentShape(Rectangle())
            .onTapGesture { onCancel() } // tap outside to close
            
            // MARK: Card
            VStack(spacing: 0) {
                // --- Header ---
                HStack {
                    Text("Change Date")
                        .appFont(AppFont.title3)
                        .foregroundColor(Color("White"))
                    Spacer()
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(Color("White"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 21)
                .padding(.leading, 25)
                .padding(.trailing, 23)
                
                // --- divider ---
                Divider()
                    .frame(width: 329)
                    .background(Color("Neutral-800"))
                    .padding(.top, 18)
                
                // --- Calendar (custom) ---
                CustomCalendar(selectedDate: $pickedDate)
                
                // --- Confirm button ---
                Button {
                    onConfirm(pickedDate)
                } label: {
                    Text("Confirm")
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .appFont(AppFont.title3)
                        .foregroundColor(.black)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color("Green-300"))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .frame(width: 361, height: 491) //h: 451
            .background( // of the card
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.black)).opacity(0.5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            )
            .overlay(
                // stroke
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
        }
        .navBarHidden(true)
    }
}
