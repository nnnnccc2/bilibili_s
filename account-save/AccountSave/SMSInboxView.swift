import SwiftUI
import SwiftData

/// 凭证存储：按账号分组，记录每个账号用哪个手机号注册。
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
                .navigationTitle("凭证存储")
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索账号、手机号或短信"
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
            "删除凭证?",
            isPresented: isConfirmingAccountDelete,
            presenting: accountToDelete
        ) { account in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { delete(account) }
        } message: { account in
            Text("将删除 \(account.name) 及其下所有记录。")
        }
    }

    @ViewBuilder
    private var content: some View {
        if accounts.isEmpty {
            ContentUnavailableView {
                Label("还没有保存凭证", systemImage: "lock.shield")
            } description: {
                Text("在「快捷指令」中添加「保存登录凭证短信」动作，收到的账号验证码短信会自动归档到这里。")
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
                        AccountRowView(account: account, allAccounts: displayedAccounts)
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
                    Label("配置快捷指令", systemImage: "questionmark.circle")
                }
                Divider()
                Button {
                    export(kind: .accounts)
                } label: {
                    Label("导出账号清单（Excel）", systemImage: "tablecells")
                }
                Button {
                    export(kind: .messages)
                } label: {
                    Label("导出全部短信（CSV）", systemImage: "doc.text")
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

/// 凭证列表行：图标 + 账号名（主） + 注册手机号（次）。
/// 同应用不同手机号注册的账号，手机号用彩色 tag 区分。
struct AccountRowView: View {
    let account: Account
    /// 所有账号，用于判断是否有同名账号需要靠手机号 tag 区分。
    let allAccounts: [Account]

    /// 同名字段数量 ≥ 2 时，手机号要渲染成 tag 以便区分。
    private var needsPhoneTag: Bool {
        allAccounts.filter { $0.name == account.name }.count >= 2
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MerchantIconView(name: account.name, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)

                if account.phoneNumber.isEmpty {
                    Text("未填写")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                } else if needsPhoneTag {
                    phoneTag
                } else {
                    Text(account.phoneNumber)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    /// 彩色 tag：背景色从手机号稳定 hash 得到，同手机号永远同色。
    private var phoneTag: some View {
        let bg = PhoneTagColor.color(for: account.phoneNumber)
        return Text(account.phoneNumber)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(bg.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg.background, in: Capsule())
    }
}

/// 手机号 tag 的颜色池：从手机号 hash 里稳定取色。
enum PhoneTagColor {
    struct Palette {
        let background: Color
        let foreground: Color
    }

    private static let palettes: [Palette] = [
        Palette(background: Color(red: 0.90, green: 0.96, blue: 1.00), foreground: Color(red: 0.00, green: 0.35, blue: 0.72)),
        Palette(background: Color(red: 0.90, green: 1.00, blue: 0.94), foreground: Color(red: 0.00, green: 0.45, blue: 0.18)),
        Palette(background: Color(red: 1.00, green: 0.93, blue: 0.93), foreground: Color(red: 0.78, green: 0.12, blue: 0.12)),
        Palette(background: Color(red: 0.97, green: 0.93, blue: 1.00), foreground: Color(red: 0.40, green: 0.16, blue: 0.75)),
        Palette(background: Color(red: 1.00, green: 0.97, blue: 0.88), foreground: Color(red: 0.60, green: 0.40, blue: 0.00)),
        Palette(background: Color(red: 0.92, green: 0.94, blue: 0.98), foreground: Color(red: 0.22, green: 0.28, blue: 0.40)),
        Palette(background: Color(red: 0.98, green: 0.90, blue: 0.96), foreground: Color(red: 0.70, green: 0.14, blue: 0.48)),
        Palette(background: Color(red: 0.88, green: 0.98, blue: 0.97), foreground: Color(red: 0.05, green: 0.55, blue: 0.52))
    ]

    static func color(for phone: String) -> Palette {
        let seed = phone.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return palettes[abs(seed) % palettes.count]
    }
}
