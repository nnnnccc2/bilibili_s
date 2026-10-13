//
//  AccountStore.swift
//  AccountKeeper
//
//  Data persistence using UserDefaults
//

import Foundation

class AccountStore: ObservableObject {
    @Published var accounts: [AccountItem] = []

    private let storageKey = "AccountKeeper.accounts"

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            accounts = []
            return
        }
        if let decoded = try? JSONDecoder().decode([AccountItem].self, from: data) {
            accounts = decoded
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
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
