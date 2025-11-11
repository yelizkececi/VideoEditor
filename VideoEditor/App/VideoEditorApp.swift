//
//  VideoEditorApp.swift
//  VideoEditor
//
//  Created on 8.11.25.
//

import SwiftUI

@main
struct VideoEditorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
