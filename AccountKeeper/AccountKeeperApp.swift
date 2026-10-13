//
//  AccountKeeperApp.swift
//  BiliBili
//
//  App entry point for the BiliBili third-party client
//

import SwiftUI

// MARK: - Bilibili theme colors

extension Color {
    /// Bilibili brand blue (#2A9DF4) — primary accent
    static let biliBlue = Color(red: 42/255, green: 157/255, blue: 244/255)
    /// Light blue gradient start for page backgrounds
    static let biliGradientTop = Color(red: 191/255, green: 227/255, blue: 249/255)
    /// Light blue gradient end for page backgrounds
    static let biliGradientBottom = Color(red: 232/255, green: 244/255, blue: 253/255)
    /// Card surface color (soft white with blue tint)
    static let biliCard = Color(red: 248/255, green: 251/255, blue: 254/255)
    /// Subtle border for cards
    static let biliBorder = Color(red: 220/255, green: 232/255, blue: 243/255)
}

/// Linear gradient used as the default page background (light blue)
let biliBackgroundGradient = LinearGradient(
    colors: [.biliGradientTop, .biliGradientBottom],
    startPoint: .top,
    endPoint: .bottom
)

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
