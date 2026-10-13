//
//  ContentView.swift
//  AccountKeeper
//
//  Main account list view
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AccountStore
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @State private var editingAccount: AccountItem?

    private let categories = ["全部"] + AccountItem.categories

    var filteredAccounts: [AccountItem] {
        var result = store.accounts
        if selectedCategory != "全部" {
            result = result.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            result = result.filter { account in
                account.name.localizedCaseInsensitiveContains(searchText) ||
                account.username.localizedCaseInsensitiveContains(searchText) ||
                account.url.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Text(cat)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(selectedCategory == cat ? Color.accentColor : Color(.systemGray6))
                                    .foregroundStyle(selectedCategory == cat ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Account list
                List {
                    if filteredAccounts.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "还没有账号" : "没有匹配的账号",
                            systemImage: "tray",
                            description: Text(searchText.isEmpty ? "点击右上角 + 添加你的第一个账号" : "试试其他关键词")
                        )
                    } else {
                        ForEach(filteredAccounts) { account in
                            AccountRowView(account: account)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingAccount = account
                                }
                        }
                        .onDelete { offsets in
                            let toDelete = offsets.map { filteredAccounts[$0] }
                            for account in toDelete {
                                store.delete(account)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("账号管家")
            .searchable(text: $searchText, prompt: "搜索应用、账号或网址")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AccountEditView(account: nil)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(store)
            }
            .sheet(item: $editingAccount) { account in
                AccountEditView(account: account)
                    .environmentObject(store)
            }
        }
    }
}

struct AccountRowView: View {
    let account: AccountItem

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(account.name.prefix(1)).uppercased())
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.headline)
                if !account.username.isEmpty {
                    Text(account.username)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !account.url.isEmpty {
                    Text(account.url)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(AccountStore())
}
