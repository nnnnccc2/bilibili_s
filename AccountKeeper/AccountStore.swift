//
//  AccountStore.swift
//  AccountKeeper
//
//  Data persistence using UserDefaults + App Group (shared with AutoFill extension)
//

import Foundation

class AccountStore: ObservableObject {
    @Published var accounts: [AccountItem] = []

    private let storageKey = "AccountKeeper.accounts"
    private let appGroupID = "group.com.example.AccountKeeper"

    init() {
        load()
    }

    func load() {
        // Prefer App Group shared data, fall back to local
        if let shared = UserDefaults(suiteName: appGroupID),
           let data = shared.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([AccountItem].self, from: data) {
            accounts = decoded
            return
        }
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([AccountItem].self, from: data) {
            accounts = decoded
        }
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(accounts) else { return }
        // Save to both local and App Group for extension access
        UserDefaults.standard.set(encoded, forKey: storageKey)
        UserDefaults(suiteName: appGroupID)?.set(encoded, forKey: storageKey)
    }

    func add(_ account: AccountItem) {
        accounts.append(account)
        save()
    }

    func update(_ account: AccountItem) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            var updated = account
            updated.updatedAt = Date()
            accounts[index] = updated
            save()
        }
    }

    func delete(_ account: AccountItem) {
        accounts.removeAll { $0.id == account.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        accounts.remove(atOffsets: offsets)
        save()
    }
}
