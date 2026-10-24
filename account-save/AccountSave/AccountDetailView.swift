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

    private let cardRadius: CGFloat = 10

    private var messages: [SMSMessage] { account.sortedMessages }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard

                if messages.isEmpty {
                    Text("暂无短信")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color(.secondarySystemGroupedBackground), in: cardShape)
                } else {
                    ForEach(messages) { message in
                        SwipeDeleteMessageRow(message: message, radius: cardRadius) {
                            delete(message)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
        .alert("删除凭证?", isPresented: $isConfirmingDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteAccount() }
        } message: {
            Text("将删除 \(account.name) 及其下所有记录。")
        }
        .alert("导出失败", isPresented: exportErrorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            MerchantIconView(name: account.name, size: 58)
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 5) {
                Text(account.name)
                    .font(.system(size: 21, weight: .semibold))

                Text(account.phoneNumber.isEmpty ? "未填写手机号" : account.phoneNumber)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(account.phoneNumber.isEmpty ? .tertiary : .secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [brandTint.opacity(0.14), Color(.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: cardShape
        )
    }

    /// 品牌色，用于顶部卡片淡色底。
    private var brandTint: Color {
        MerchantIcon.brand(for: account.name)?.color ?? .accentColor
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button {
                    isEditing = true
                } label: {
                    Label("编辑凭证信息", systemImage: "pencil")
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
                    Label("删除凭证", systemImage: "trash")
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

    private func delete(_ message: SMSMessage) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(message)
            try? modelContext.save()
        }
    }

    private func deleteAccount() {
        modelContext.delete(account)
        try? modelContext.save()
        dismiss()
    }
}

/// 可左滑出删除按钮的短信卡片：滑出的红色区块与卡片同圆角。
struct SwipeDeleteMessageRow: View {
    let message: SMSMessage
    let radius: CGFloat
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isRevealed = false

    private let buttonWidth: CGFloat = 88

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: deleteNow) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 19, weight: .regular))
                    Text("删除")
                        .font(.system(size: 15))
                }
                .foregroundStyle(.white)
                .frame(width: buttonWidth)
                .frame(maxHeight: .infinity)
                .background(Color(.systemRed))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            MessageRowView(message: message)
                .background(Color(.secondarySystemGroupedBackground))
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture(perform: closeIfNeeded)
                .gesture(dragGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let projected = base + value.translation.width
                offset = min(0, max(-buttonWidth - 30, projected))
            }
            .onEnded { value in
                let projected = base + value.translation.width
                if projected <= -buttonWidth - 30 {
                    deleteNow()
                } else if projected < -buttonWidth * 0.5 {
                    withAnimation(.easeOut(duration: 0.18)) { offset = -buttonWidth }
                    isRevealed = true
                } else {
                    withAnimation(.easeOut(duration: 0.18)) { offset = 0 }
                    isRevealed = false
                }
            }
    }

    /// 已滑出时以 -buttonWidth 为基准继续计算拖动距离。
    private var base: CGFloat { isRevealed ? -buttonWidth : 0 }

    private func closeIfNeeded() {
        guard isRevealed else { return }
        withAnimation(.easeOut(duration: 0.18)) { offset = 0 }
        isRevealed = false
    }

    private func deleteNow() {
        withAnimation(.easeInOut(duration: 0.2)) {
            onDelete()
        }
    }
}

/// 单条短信：发件号码 + 时间 + 内容，识别到验证码时显示一键复制。
struct MessageRowView: View {
    let message: SMSMessage

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DateText.absolute(message.receivedAt))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(message.content)
                .font(.system(size: 17))
                .fixedSize(horizontal: false, vertical: true)

            if let code = VerificationCode.extract(from: message.content) {
                Button {
                    copy(code)
                } label: {
                    HStack(spacing: 6) {
                        Text(code)
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                        Text(didCopy ? "已复制" : "复制验证码")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
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
