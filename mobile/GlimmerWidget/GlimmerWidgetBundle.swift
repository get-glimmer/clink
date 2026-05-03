import WidgetKit
import SwiftUI

@main
struct GlimmerWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlimmerTaskListWidget()
        GlimmerShakerWidget()
    }
}
