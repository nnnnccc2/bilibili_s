import SwiftUI
import SwiftData
import UIKit

/// 账号详情：账号信息 + 该账号下的短信。
struct AccountDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: Account

    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    private let cardShape: RoundedRectangle = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                messagesCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $isEditing) {
            AccountEditorView(account: account)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .confirmationDialog(
            "删除账号后，该账号下的短信也会一并删除。",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("删除账号", role: .destructive) { deleteAccount() }
        }
        .alert("导出失败", isPresented: exportErrorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            MerchantIconView(name: account.name, size: 60)

            VStack(alignment: .leading, spacing: 6) {
                Text(account.name)
                    .font(.system(size: 22, weight: .semibold))
                Text("\(account.senderCount) 个号码 / \(account.messages.count) 条短信")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                Text("注册手机号：\(account.phoneNumberText)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: cardShape)
    }

    @ViewBuilder
    private var messagesCard: some View {
        let messages = account.sortedMessages
        if messages.isEmpty {
            Text("暂无短信")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.secondarySystemGroupedBackground), in: cardShape)
        } else {
            VStack(spacing: 0) {
                ForEach(messages.indices, id: \.self) { index in
                    if index > 0 {
                        Divider().padding(.leading, 16)
                    }
                    MessageRowView(message: messages[index])
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: cardShape)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button {
                    isEditing = true
                } label: {
                    Label("编辑账号与手机号", systemImage: "pencil")
                }
                Button {
                    exportMessages()
                } label: {
                    Label("导出该账号短信（CSV）", systemImage: "doc.text")
                }
                Divider()
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("删除账号", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }

    private func exportMessages() {
        do {
            shareItem = ShareItem(url: try ExportService.exportMessages([account]))
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteAccount() {
        modelContext.delete(account)
        try? modelContext.save()
        dismiss()
    }
}

/// 单条短信：发件号码 + 时间 + 内容，识别到验证码时显示一键复制。
struct MessageRowView: View {
    let message: SMSMessage

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.senderText)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(DateText.absolute(message.receivedAt))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Text(message.content)
                .font(.system(size: 17))
                .fixedSize(horizontal: false, vertical: true)

            if let code = VerificationCode.extract(from: message.content) {
                Button {
                    copy(code)
                } label: {
                    HStack(spacing: 6) {
                        Text("验证码 \(code)")
                        Image(systemName: didCopy ? "checkmark.square" : "doc.on.doc")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copy(_ code: String) {
        UIPasteboard.general.string = code
        didCopy = true
    }
}
