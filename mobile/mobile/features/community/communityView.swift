//
//  homeView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI

struct CommunityView: View {
    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()
            Text("Community View")
                .foregroundColor(AppColors.textWhite)
        }
    }
}

#Preview {
    AppRouter()
}
