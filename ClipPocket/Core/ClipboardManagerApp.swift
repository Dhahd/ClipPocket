//
//  ClipboardManagerApp.swift
//  ClipPocket
//
//  Created by Shaneen on 10/15/24.
//

import SwiftUI



@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        
        Settings {
            SettingsView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        EmptyView()
            .frame(width: 0, height: 0)
            .hidden()
    }
}
