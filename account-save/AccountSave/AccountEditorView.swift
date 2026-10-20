import SwiftUI
import SwiftData

/// 编辑凭证：账号名与注册手机号。
struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let account: Account

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
                    Text("账号名用于快捷指令弹窗输入后归档凭证；注册手机号是账号用哪个手机号注册的，会自动写入并在主列表展示。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("编辑凭证信息")
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
                name = account.name
                phoneNumber = account.phoneNumber
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        account.name = trimmedName
        account.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
        try? modelContext.save()
        dismiss()
    }
}
