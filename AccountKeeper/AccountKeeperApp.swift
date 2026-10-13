//
//  AccountKeeperApp.swift
//  BiliBili
//
//  App entry point for the BiliBili third-party client
//

import SwiftUI

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
