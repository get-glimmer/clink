//
//  GlimmerWidgetLiveActivity.swift
//  GlimmerWidget
//
//  Created by Soohyeuk Choi on 3/7/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct GlimmerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct GlimmerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlimmerWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension GlimmerWidgetAttributes {
    fileprivate static var preview: GlimmerWidgetAttributes {
        GlimmerWidgetAttributes(name: "World")
    }
}

extension GlimmerWidgetAttributes.ContentState {
    fileprivate static var smiley: GlimmerWidgetAttributes.ContentState {
        GlimmerWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: GlimmerWidgetAttributes.ContentState {
         GlimmerWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: GlimmerWidgetAttributes.preview) {
   GlimmerWidgetLiveActivity()
} contentStates: {
    GlimmerWidgetAttributes.ContentState.smiley
    GlimmerWidgetAttributes.ContentState.starEyes
}
