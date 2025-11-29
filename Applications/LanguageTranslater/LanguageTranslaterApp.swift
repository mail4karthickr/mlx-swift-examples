//
//  LanguageTranslaterApp.swift
//  LanguageTranslater
//
//  Created by Karthick Ramasamy on 28/11/25.
//

import SwiftUI

@main
struct LanguageTranslaterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS)
                .frame(minWidth: 600, minHeight: 700)
            #endif
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }
}
