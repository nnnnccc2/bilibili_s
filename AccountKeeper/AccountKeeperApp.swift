//
//  AccountKeeperApp.swift
//  AccountKeeper
//
//  A simple account keeper app - remember which apps/sites you have accounts for
//

import SwiftUI

@main
struct AccountKeeperApp: App {
    @StateObject private var store = AccountStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
