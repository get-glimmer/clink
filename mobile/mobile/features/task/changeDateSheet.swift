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
            // Dim background behind the card
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial).opacity(0.9)
                    .ignoresSafeArea()

                Color.black.opacity(0.8)
                    .ignoresSafeArea()
            }
            .contentShape(Rectangle())
            .onTapGesture {        // tap outside to close
                onCancel()
                dismiss()
            }

            // Card
            VStack(spacing: 10) {
                // --- Header ---
                HStack {
                    Text("Change Date")
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
                
                // --- divider ---
                Divider()
                    .frame(width: 329)
                    .background(Color("Neutral-800"))

                // --- Calendar ---
                // Using Apple's graphical DatePicker
                DatePicker(
                    "Select a date",
                    selection: $pickedDate,
                    displayedComponents: [.date]
                )
                .padding(.horizontal, 4)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Color("Green-300"))// selected day pill color
                .environment(\.locale, Locale(identifier: "en_US"))

                // --- Confirm button ---
                Button {
                    onConfirm(pickedDate)
                    dismiss()
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
                .padding(.bottom, 8)
            }
            .padding(16)
            .frame(width: 361, height: 481) //h: 451
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
            .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 14)
        }
        
    }
}
