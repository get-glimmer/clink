//
//  communityModel.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI

struct Friend: Identifiable {
    let id = UUID()
    let userId: String // Database user ID for fetching their tasks
    let name: String
    let profileImageName: String
    let progress: Double // 0.0 to 1.0
    let emojis: [String]
    let isSelected: Bool
    let isFavorite: Bool
}

struct CommunityData {
    let friends: [Friend]
    let selectedCategory: String
}
