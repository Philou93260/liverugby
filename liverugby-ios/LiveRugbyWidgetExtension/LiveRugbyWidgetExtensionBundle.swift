//
//  LiveRugbyWidgetExtensionBundle.swift
//  LiveRugbyWidgetExtension
//
//  Point d'entrée pour la Widget Extension
//

import WidgetKit
import SwiftUI

@main
struct LiveRugbyWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            MatchLiveActivityWidget()
        }
    }
}
