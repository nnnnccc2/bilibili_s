//
//  AccountEditView.swift
//  AccountKeeper
//
//  Add or edit an account
//

import SwiftUI

struct AccountEditView: View {
    @EnvironmentObject var store: AccountStore
    @Environment(\.dismiss) private var dismiss

    let account: AccountItem?

    @State private var name: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var url: String = ""
    @State private var note: String = ""
    @State private var category: String = "其他"

    private var isEditing: Bool { account != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("应用 / 网站名称", text: $name)
                    TextField("账号", text: $username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    SecureField("密码（可选）", text: $password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section("网址与分类") {
                    TextField("网址", text: $url)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Picker("分类", selection: $category) {
                        ForEach(AccountItem.categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }

                Section("备注") {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            if let account = account {
                                store.delete(account)
                                dismiss()
                            }
                        } label: {
                            Label("删除此账号", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑账号" : "添加账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let account = account {
                    name = account.name
                    username = account.username
                    password = account.password
                    url = account.url
                    note = account.note
                    category = account.category
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = account {
            var updated = existing
            updated.name = trimmedName
            updated.username = username
            updated.password = password
            updated.url = url
            updated.note = note
            updated.category = category
            store.update(updated)
        } else {
            let newAccount = AccountItem(
                name: trimmedName,
                username: username,
                password: password,
                url: url,
                note: note,
                category: category
            )
            store.add(newAccount)
        }
        dismiss()
    }
}

#Preview {
    AccountEditView(account: nil)
        .environmentObject(AccountStore())
}
