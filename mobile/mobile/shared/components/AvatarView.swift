//
//  AvatarView.swift
//  mobile
//
//  Shared avatar component with URL-aware loading and consistent fallback style.
//

import SwiftUI
import UIKit

struct AvatarView: View {
    let imageURLOrName: String?
    let size: CGFloat

    init(imageURLOrName: String?, size: CGFloat) {
        self.imageURLOrName = imageURLOrName
        self.size = size
    }

    var body: some View {
        let glyphSize: CGFloat = size * 0.62
        let fallbackAvatar = AnyView(
            ZStack {
                Circle()
                    .fill(AppColors.neutral800)
                Image("profile")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(AppColors.textWhite)
                    .frame(width: glyphSize, height: glyphSize)
                Circle()
                    .stroke(AppColors.neutral700, lineWidth: 1)
            }
            .frame(width: size, height: size)
        )

        if let value = imageURLOrName,
           value.lowercased().hasPrefix("http"),
           let url = URL(string: value) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    fallbackAvatar
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    fallbackAvatar
                @unknown default:
                    fallbackAvatar
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else if let value = imageURLOrName, !value.isEmpty {
            // Only use an asset image if it actually exists, otherwise show fallback
            if UIImage(named: value) != nil {
                Image(value)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallbackAvatar
                    .clipShape(Circle())
            }
        } else {
            fallbackAvatar
                .clipShape(Circle())
        }
    }
}


