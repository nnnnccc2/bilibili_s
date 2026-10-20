import SwiftUI
import SwiftData

/// 账本纸张色：暖米白，模拟账本内页。
extension Color {
    static let ledgerPaper = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let ledgerCard = Color(red: 0.99, green: 0.98, blue: 0.95)
    static let ledgerLine = Color(red: 0.82, green: 0.78, blue: 0.70)
}

/// 凭证存储：按账号名聚合，一眼看到某应用有哪些手机号注册过。
struct SMSInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt, order: .reverse) private var accounts: [Account]

    @State private var searchText = ""
    @State private var isShowingGuide = false
    @State private var shareItem: ShareItem?
    @State private var exportError: String?
    @State private var groupToDelete: AccountGroup?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("凭证存储")
                .toolbarColorScheme(.light, for: .navigationBar)
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索账号、手机号或短信"
                )
                .toolbar { toolbarContent }
                .background(Color.ledgerPaper.ignoresSafeArea())
        }
        .tint(.brown)
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
            isPresented: isConfirmingGroupDelete,
            presenting: groupToDelete
        ) { group in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { delete(group) }
        } message: { group in
            Text("将删除账号 \(group.name) 及其下所有记录。")
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
        } else if displayedGroups.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List {
                ForEach(displayedGroups) { group in
                    NavigationLink {
                        AccountGroupDetailView(group: group)
                    } label: {
                        AccountGroupRowView(group: group)
                    }
                    .listRowBackground(Color.ledgerPaper)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            groupToDelete = group
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSeparatorTint(Color.ledgerLine)
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

    // MARK: - 按账号名聚合 + 搜索 + 排序

    /// 按账号名聚合后得到的列表。每个 group 的 accounts 按最近短信时间倒序。
    private var allGroups: [AccountGroup] {
        let dict = Dictionary(grouping: accounts, by: { $0.name })
        return dict.map { name, accts in
            let sorted = accts.sorted { lhs, rhs in
                let left = lhs.latestMessage?.receivedAt ?? lhs.createdAt
                let right = rhs.latestMessage?.receivedAt ?? rhs.createdAt
                return left > right
            }
            return AccountGroup(name: name, accounts: sorted)
        }
    }

    /// 搜索匹配：命中组里任意一个账号就保留整组。
    private var displayedGroups: [AccountGroup] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        let matched = keyword.isEmpty ? allGroups : allGroups.compactMap { group in
            let filtered = group.accounts.filter { account in
                account.name.localizedCaseInsensitiveContains(keyword)
                    || account.phoneNumber.contains(keyword)
                    || account.messages.contains { message in
                        message.content.localizedCaseInsensitiveContains(keyword)
                            || message.sender.contains(keyword)
                    }
            }
            return filtered.isEmpty ? nil : AccountGroup(name: group.name, accounts: filtered)
        }
        // 组之间按该组最新一条短信时间倒序。
        return matched.sorted { lhs, rhs in
            let left = lhs.accounts.first?.latestMessage?.receivedAt ?? lhs.accounts.first?.createdAt ?? Date.distantPast
            let right = rhs.accounts.first?.latestMessage?.receivedAt ?? rhs.accounts.first?.createdAt ?? Date.distantPast
            return left > right
        }
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }

    private var isConfirmingGroupDelete: Binding<Bool> {
        Binding(
            get: { groupToDelete != nil },
            set: { if !$0 { groupToDelete = nil } }
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

    private func delete(_ group: AccountGroup) {
        for account in group.accounts {
            modelContext.delete(account)
        }
        try? modelContext.save()
    }
}

/// 按账号名聚合后的值类型（列表和详情共用）。
struct AccountGroup: Identifiable, Hashable {
    let name: String
    var accounts: [Account]

    var id: String { name }

    /// 所有注册手机号（去空、去重）。
    var phones: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for account in accounts where !account.phoneNumber.isEmpty {
            if seen.insert(account.phoneNumber).inserted {
                result.append(account.phoneNumber)
            }
        }
        return result
    }
}

// MARK: - 主列表行（按账号名聚合）

/// 聚合行：品牌图标 + 账号名 + 注册手机号（普通文字）。
struct AccountGroupRowView: View {
    let group: AccountGroup

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MerchantIconView(name: group.name, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)

                if group.phones.isEmpty {
                    Text("未填写手机号")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                } else {
                    // 同一账号下的每个注册手机号各占一行，清晰列出。
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(group.phones, id: \.self) { phone in
                            Text(phone)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - 按账号名聚合的详情页

/// 账号详情：顶部账号简介，下面按手机号列出，点击进入该手机号的短信列表。
struct AccountGroupDetailView: View {
    let group: AccountGroup
    @Environment(\.modelContext) private var modelContext

    @State private var accountToDelete: Account?

    var body: some View {
        VStack(spacing: 0) {
            headerCard
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            List {
                ForEach(group.accounts) { account in
                    NavigationLink {
                        AccountDetailView(account: account)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Text(account.phoneNumber.isEmpty ? "未填写手机号" : account.phoneNumber)
                                .font(.system(size: 17))
                        }
                        .padding(.vertical, 14)
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
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(Color.ledgerPaper.ignoresSafeArea())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.brown)
        .alert(
            "删除凭证?",
            isPresented: isConfirmingAccountDelete,
            presenting: accountToDelete
        ) { account in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { delete(account) }
        } message: { account in
            Text("将删除账号 \(account.name)（\(account.phoneNumberText)）及其下所有记录。")
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            MerchantIconView(name: group.name, size: 62)

            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.system(size: 22, weight: .semibold))
                if !group.phones.isEmpty {
                    Text(group.phones.joined(separator: "、"))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.ledgerCard)
        )
    }

    private var isConfirmingAccountDelete: Binding<Bool> {
        Binding(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )
    }

    private func delete(_ account: Account) {
        modelContext.delete(account)
        try? modelContext.save()
    }
}
