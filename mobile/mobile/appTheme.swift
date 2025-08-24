import SwiftUI

enum AppColors {
    // MARK: - Green Shades
    static let green900 = Color("Green-900")
    static let green800 = Color("Green-800")
    static let green700 = Color("Green-700")
    static let green600 = Color("Green-600")
    static let green500 = Color("Green-500")
    static let green400 = Color("Green-400")
    static let green300 = Color("Green-300")
    static let green200 = Color("Green-200")
    static let green100 = Color("Green-100")
    static let green50  = Color("Green-50")

    // MARK: - Neutral Shades
    static let neutral1000 = Color("Neutral-1000")
    static let neutral900  = Color("Neutral-900")
    static let neutral800  = Color("Neutral-800")
    static let neutral700  = Color("Neutral-700")
    static let neutral600  = Color("Neutral-600")
    static let neutral500  = Color("Neutral-500")
    static let neutral400  = Color("Neutral-400")
    static let neutral300  = Color("Neutral-300")
    static let neutral200  = Color("Neutral-200")
    static let neutral100  = Color("Neutral-100")
    static let neutral50   = Color("Neutral-50")
    static let white       = Color("White")
    static let textWhite = Color.white
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
