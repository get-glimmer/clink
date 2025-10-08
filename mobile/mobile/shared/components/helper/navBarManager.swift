import SwiftUI

// PreferenceKey to bubble up "nav bar hidden" intent from child views.
struct NavBarHiddenPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        // If any child says "hidden", we hide it.
        value = value || nextValue()
    }
}

// View modifier for declaring nav bar hidden intent.
struct NavBarHiddenModifier: ViewModifier {
    let hidden: Bool
    func body(content: Content) -> some View {
        content
            // Publish the intent upward in the view tree.
            .preference(key: NavBarHiddenPreferenceKey.self, value: hidden)
    }
}

extension View {
    // Attach on any overlay/sheet that should hide the custom nav bar.
    // Example: .navBarHidden(true) while this view is present.
    func navBarHidden(_ hidden: Bool) -> some View {
        self.modifier(NavBarHiddenModifier(hidden: hidden))
    }
}
