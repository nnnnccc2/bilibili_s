//
//  AccountKeeperApp.swift
//  BiliBili
//
//  App entry point for the BiliBili third-party client
//

import SwiftUI

// MARK: - Bilibili theme colors (MiniBili-style clean theme)

extension Color {
    /// Primary brand blue (#0DA2E7) — matches the reference design
    static let biliBlue = Color(red: 13/255, green: 162/255, blue: 231/255)
    /// Page background (#F5FBFF)
    static let biliBackground = Color(red: 245/255, green: 251/255, blue: 255/255)
    /// Hero background behind the top bar (#A7D8F0)
    static let biliHero = Color(red: 167/255, green: 216/255, blue: 240/255)
    /// Card surface color — pure white
    static let biliCard = Color.white
    /// Subtle border for cards
    static let biliBorder = Color(red: 230/255, green: 232/255, blue: 235/255)
    /// Primary text (#0F172A)
    static let biliText = Color(red: 15/255, green: 23/255, blue: 42/255)
    /// Secondary text (#65758B)
    static let biliSubtext = Color(red: 101/255, green: 117/255, blue: 139/255)
    /// Unselected tab text (#475569)
    static let biliTabText = Color(red: 71/255, green: 85/255, blue: 105/255)
    /// Muted icon (#94A3B8)
    static let biliMuted = Color(red: 148/255, green: 163/255, blue: 184/255)
    /// Muted surface / placeholder (#F1F5F9)
    static let biliMutedSurface = Color(red: 241/255, green: 245/255, blue: 249/255)
}

/// Page background — solid clean color (no heavy gradient for performance)
let biliBackgroundGradient = Color.biliBackground

@main
struct BiliBiliApp: App {
    @StateObject private var store = AppStore()

    init() {
        // Large shared URL cache so cover/avatar images load instantly on
        // scroll-back and do not cause jank from repeated network fetches.
        let memoryCap = 64 * 1024 * 1024   // 64 MB in-memory
        let diskCap = 256 * 1024 * 1024     // 256 MB on-disk
        let cache = URLCache(memoryCapacity: memoryCap, diskCapacity: diskCap, diskPath: "BiliBiliImages")
        URLCache.shared = cache
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
