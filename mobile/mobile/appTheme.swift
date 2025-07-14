import SwiftUI

enum AppColors {
    static let primary = Color("AppPrimaryColor")
    static let secondary = Color("AppSecondaryColor")
}

enum AppFonts {
    static func heading(size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    static func body(size: CGFloat) -> Font {
        .system(size: size)
    }
}

enum AppSpacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}