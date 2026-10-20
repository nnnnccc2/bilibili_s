import SwiftUI
import SwiftData

/// 凭证存储：按账号名聚合，一眼看到某应用有哪些手机号注册过。
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
            Text("将删除账号 \(account.name)（\(account.phoneNumberText)）及其下所有记录。")
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

    /// 触发删除确认弹窗。
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

/// 按账号名聚合后的值类型（列表和详情共用）。
struct AccountGroup: Identifiable, Hashable {
    let name: String
    var accounts: [Account]

    var id: String { name }

    /// 该账号名一共用了多少个手机号注册。
    var phoneCount: Int { Set(accounts.map(\.phoneNumber)).count }

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

/// 聚合行：品牌图标 + 账号名 + 多个手机号 tag（横排 Wrap）。
struct AccountGroupRowView: View {
    let group: AccountGroup

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MerchantIconView(name: group.name, size: 46)

            VStack(alignment: .leading, spacing: 5) {
                Text(group.name)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)

                if group.phones.isEmpty {
                    Text("未填写注册手机号")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                } else {
                    // 一行最多 3 个 tag，多了显示 +N。
                    HStack(spacing: 6) {
                        ForEach(group.phones.prefix(3), id: \.self) { phone in
                            PhoneTagView(phone: phone)
                        }
                        if group.phones.count > 3 {
                            Text("+\(group.phones.count - 3)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

/// 一个手机号 tag（彩色胶囊）。
struct PhoneTagView: View {
    let phone: String

    var body: some View {
        let palette = PhoneTagColor.color(for: phone)
        return Text(phone)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(palette.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(palette.background, in: Capsule())
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

// MARK: - 按账号名聚合的详情页

/// 同一账号名下多个手机号账号一起展示的详情页。
struct AccountGroupDetailView: View {
    let group: AccountGroup
    @Environment(\.dismiss) private var dismiss

    @State private var accountToDelete: Account?
    @State private var showExport = false
    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    var body: some View {
        List {
            Section {
                headerCard
            }

            ForEach(group.accounts) { account in
                Section {
                    NavigationLink {
                        AccountDetailView(account: account)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(account.phoneNumber.isEmpty ? "未填写手机号" : account.phoneNumber)
                                    .font(.system(size: 15, weight: .semibold))
                                if account.messages.isEmpty {
                                    Text("· 无短信")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Text(subtitle(for: account))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            accountToDelete = account
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                } header: {
                    HStack {
                        Text(group.accounts.count > 1 ? "注册手机号" : "注册手机号")
                        Spacer()
                        if !account.messages.isEmpty {
                            Text("\(account.messages.count) 条短信")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exportGroupMessages()
                    } label: {
                        Label("导出该账号名全部短信（CSV）", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
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
            Text("将删除账号 \(account.name)（\(account.phoneNumberText)）及其下所有记录。")
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            MerchantIconView(name: group.name, size: 62)

            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.system(size: 22, weight: .semibold))
                Text("\(group.phones.count) 个手机号注册过")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(group.phones.prefix(4), id: \.self) { phone in
                        PhoneTagView(phone: phone)
                    }
                    if group.phones.count > 4 {
                        Text("+\(group.phones.count - 4)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(4)
    }

    private func subtitle(for account: Account) -> String {
        guard let latest = account.latestMessage else { return "还没有短信记录" }
        return latest.content.replacingOccurrences(of: "\n", with: " ")
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }

    private var isConfirmingAccountDelete: Binding<Bool> {
        Binding(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )
    }

    private func exportGroupMessages() {
        do {
            let url = try ExportService.exportMessages(group.accounts)
            shareItem = ShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func delete(_ account: Account) {
        let context = account.modelContext
        context?.delete(account)
        try? context?.save()
    }
}
