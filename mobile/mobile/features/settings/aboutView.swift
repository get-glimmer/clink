import SwiftUI

struct AboutView: View {
    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()
            Text("about View")
                .foregroundColor(AppColors.textWhite)
        }
    }
}
