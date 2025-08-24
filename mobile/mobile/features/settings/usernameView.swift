import SwiftUI

struct UsernameView: View {
    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()
            Text("username View")
                .foregroundColor(AppColors.textWhite)
        }
    }
}
