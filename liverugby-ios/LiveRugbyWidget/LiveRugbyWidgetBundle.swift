//
//  LiveRugbyWidgetBundle.swift
//  LiveRugbyWidget
//
//  Point d'entrée principal pour le widget extension
//

import WidgetKit
import SwiftUI
import FirebaseCore

@main
struct LiveRugbyWidgetBundle: WidgetBundle {
    init() {
        // Initialiser Firebase pour le widget
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Widget {
        LiveMatchWidget()
    }
}
