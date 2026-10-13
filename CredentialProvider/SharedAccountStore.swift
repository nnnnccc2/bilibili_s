//
//  SharedAccountStore.swift
//  Shared between main app and credential provider extension
//
//  Uses App Group UserDefaults to share account data
//

import Foundation

/// App Group identifier - must match the entitlement
let kAppGroupIdentifier = "group.com.example.AccountKeeper"

/// Shared account store that works in both the main app and the extension
class SharedAccountStore {
    private let storageKey = "AccountKeeper.accounts"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: kAppGroupIdentifier)
    }

    func loadAccounts() -> [AccountItem] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([AccountItem].self, from: data)) ?? []
    }

    func saveAccounts(_ accounts: [AccountItem]) {
        guard let defaults = sharedDefaults,
              let encoded = try? JSONEncoder().encode(accounts) else { return }
        defaults.set(encoded, forKey: storageKey)
    }

    func saveAccount(_ account: AccountItem) {
        var accounts = loadAccounts()
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        saveAccounts(accounts)
    }
}
