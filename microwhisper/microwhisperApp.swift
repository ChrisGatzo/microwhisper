//
//  microwhisperApp.swift
//  microwhisper
//
//  Created by Chris Gatzonis on 2/10/25.
//

import SwiftUI

@main
struct MicrowhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.viewModel)
        }
    }
}

