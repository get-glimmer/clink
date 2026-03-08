//
//  GlimmerWidgetBundle.swift
//  GlimmerWidget
//
//  Created by Soohyeuk Choi on 3/7/26.
//

import WidgetKit
import SwiftUI

@main
struct GlimmerWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlimmerWidget()
        // GlimmerWidgetControl() - disabled, missing TimerConfiguration
        // GlimmerWidgetLiveActivity() - disabled for now
    }
}
