//
//  CredentialProviderView.swift
//  CredentialProvider
//
//  SwiftUI view for the AutoFill extension
//

import SwiftUI

struct CredentialProviderView: View {
    let serviceIdentifier: String
    let accounts: [AccountItem]
    let onSelect: (AccountItem) -> Void
    let onAdd: (AccountItem) -> Void
    let onCancel: () -> Void

    @State private var showingAddForm = false
    @State private var newName: String = ""
    @State private var newUsername: String = ""
    @State private var newPassword: String = ""
    @State private var newUrl: String = ""

    private var matchedAccounts: [AccountItem] {
        if serviceIdentifier.isEmpty {
            return accounts
        }
        return accounts.filter { account in
            let nameMatch = account.name.lowercased().contains(serviceIdentifier.lowercased())
            let urlMatch = account.url.lowercased().contains(serviceIdentifier.lowercased())
            return nameMatch || urlMatch
        }
    }

    var body: some View {
        NavigationStack {
            if showingAddForm {
                addAccountForm
            } else {
                accountList
            }
        }
    }

    private var accountList: some View {
        List {
            Section {
                Button {
                    showingAddForm = true
                } label: {
                    Label("添加新账号", systemImage: "plus.circle.fill")
                        .foregroundStyle(.accent)
                }
            }

            if !serviceIdentifier.isEmpty {
                Section("当前应用: \(serviceIdentifier)") {
                    if matchedAccounts.isEmpty {
                        Text("没有匹配的账号，点击上方添加")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(matchedAccounts) { account in
                            accountRow(account)
                        }
                    }
                }
            }

            Section("所有账号") {
                ForEach(accounts) { account in
                    accountRow(account)
                }
            }
        }
        .navigationTitle("选择账号")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消", action: onCancel)
            }
        }
    }

    private func accountRow(_ account: AccountItem) -> some View {
        Button {
            onSelect(account)
        } label: {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Text(String(account.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundStyle(.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(account.username)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "key.fill")
                    .foregroundStyle(.accent)
            }
        }
    }

    private var addAccountForm: some View {
        Form {
            Section("应用信息") {
                TextField("应用 / 网站名称", text: $newName)
                TextField("账号", text: $newUsername)
                    .autocapitalization(.none)
                SecureField("密码", text: $newPassword)
                    .autocapitalization(.none)
                TextField("网址", text: $newUrl)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }

            Section {
                Button("保存并填充") {
                    let account = AccountItem(
                        name: newName.isEmpty ? serviceIdentifier : newName,
                        username: newUsername,
                        password: newPassword,
                        url: newUrl
                    )
                    onAdd(account)
                }
                .disabled(newUsername.isEmpty || newPassword.isEmpty)
            }
        }
        .navigationTitle("添加账号")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("返回") {
                    showingAddForm = false
                }
            }
        }
        .onAppear {
            if newName.isEmpty {
                newName = serviceIdentifier
            }
        }
    }
}
