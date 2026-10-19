import SwiftUI
import SwiftData

/// 新建 / 编辑账号：账号名与注册手机号。
struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// 传入账号表示编辑，传 nil 表示新建。
    let account: Account?

    @State private var name = ""
    @State private var phoneNumber = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("账号") {
                    TextField("账号名", text: $name)
                        .textInputAutocapitalization(.never)
                    TextField("注册手机号（接收短信的手机号）", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                Section {
                    Text("账号名用于快捷指令弹窗输入后归类短信；注册手机号只用于导出的账号表格。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(account == nil ? "新建账号" : "编辑账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                name = account?.name ?? ""
                phoneNumber = account?.phoneNumber ?? ""
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let phone = phoneNumber.trimmingCharacters(in: .whitespaces)

        if let account {
            account.name = trimmedName
            account.phoneNumber = phone
        } else {
            modelContext.insert(Account(name: trimmedName, phoneNumber: phone))
        }

        try? modelContext.save()
        dismiss()
    }
}
