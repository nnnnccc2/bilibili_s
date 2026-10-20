import SwiftUI
import SwiftData

/// 短信收纳盒：按账号分组的短信列表。
struct SMSInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt, order: .reverse) private var accounts: [Account]

    @State private var searchText = ""
    @State private var isShowingGuide = false
    @State private var shareItem: ShareItem?
    @State private var exportError: String?
    @State private var accountToDelete: Account?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("短信收纳盒")
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索短信或商家"
                )
                .toolbar { toolbarContent }
        }
        .sheet(isPresented: $isShowingGuide) {
            ConfigImportView()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert("导出失败", isPresented: exportErrorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .alert(
            "删除商家会话?",
            isPresented: isConfirmingAccountDelete,
            presenting: accountToDelete
        ) { account in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { delete(account) }
        } message: { account in
            Text("将删除 \(account.name) 的会话和所有短信。")
        }
    }

    @ViewBuilder
    private var content: some View {
        if accounts.isEmpty {
            ContentUnavailableView {
                Label("还没有保存短信", systemImage: "tray")
            } description: {
                Text("在「快捷指令」中添加「导入商家短信」动作后，收到的短信会自动保存到这里。")
            } actions: {
                Button("查看配置步骤") { isShowingGuide = true }
            }
        } else if displayedAccounts.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List {
                ForEach(displayedAccounts) { account in
                    NavigationLink {
                        AccountDetailView(account: account)
                    } label: {
                        AccountRowView(account: account)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            accountToDelete = account
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    isShowingGuide = true
                } label: {
                    Label("配置导入", systemImage: "questionmark.circle")
                }
                Divider()
                Button {
                    export(kind: .accounts)
                } label: {
                    Label("导出账号列表（Excel）", systemImage: "tablecells")
                }
                Button {
                    export(kind: .messages)
                } label: {
                    Label("导出短信（CSV）", systemImage: "doc.text")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
            }
        }
    }

    /// 有短信的账号排在前面，按最近一条短信的时间倒序。
    private var displayedAccounts: [Account] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        let matched = keyword.isEmpty ? accounts : accounts.filter { account in
            account.name.localizedCaseInsensitiveContains(keyword)
                || account.phoneNumber.contains(keyword)
                || account.messages.contains { message in
                    message.content.localizedCaseInsensitiveContains(keyword)
                        || message.sender.contains(keyword)
                }
        }
        return matched.sorted { lhs, rhs in
            let left = lhs.latestMessage?.receivedAt ?? lhs.createdAt
            let right = rhs.latestMessage?.receivedAt ?? rhs.createdAt
            return left > right
        }
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }

    /// 触发删除确认弹窗：有待删账号时弹出，关闭后清空。
    private var isConfirmingAccountDelete: Binding<Bool> {
        Binding(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )
    }

    private enum ExportKind {
        case accounts
        case messages
    }

    private func export(kind: ExportKind) {
        guard accounts.contains(where: { !$0.messages.isEmpty }) || kind == .accounts else {
            exportError = "还没有可导出的短信。"
            return
        }
        do {
            let url: URL
            switch kind {
            case .accounts:
                url = try ExportService.exportAccounts(accounts)
            case .messages:
                url = try ExportService.exportMessages(accounts)
            }
            shareItem = ShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func delete(_ account: Account) {
        modelContext.delete(account)
        try? modelContext.save()
    }
}

/// 列表行：图标 + 账号名 + 最近一条短信 + 时间。
struct AccountRowView: View {
    let account: Account

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MerchantIconView(name: account.name, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Text(preview)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(timestampText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }

    private var preview: String {
        guard let message = account.latestMessage else { return "暂无短信" }
        return message.content.replacingOccurrences(of: "\n", with: " ")
    }

    private var timestampText: String {
        guard let message = account.latestMessage else { return "" }
        return DateText.relative(message.receivedAt)
    }
}
