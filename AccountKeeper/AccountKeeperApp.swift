//
//  AccountKeeperApp.swift
//  BiliBili
//
//  App entry point for the BiliBili third-party client
//

import SwiftUI

// MARK: - Bilibili theme colors (MiniBili-style clean theme)

extension Color {
    /// Bilibili brand blue (#00AEEC) — primary accent
    static let biliBlue = Color(red: 0/255, green: 174/255, blue: 236/255)
    /// Page background — clean off-white (MiniBili style)
    static let biliBackground = Color(red: 245/255, green: 246/255, blue: 248/255)
    /// Card surface color — pure white
    static let biliCard = Color.white
    /// Subtle border for cards
    static let biliBorder = Color(red: 230/255, green: 232/255, blue: 235/255)
}

/// Page background — solid clean color (no heavy gradient for performance)
let biliBackgroundGradient = Color.biliBackground

@main
struct BiliBiliApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
