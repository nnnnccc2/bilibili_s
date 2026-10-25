import SwiftUI
import SwiftData

/// 凭证存储：按账号名聚合，一眼看到某应用有哪些手机号注册过。
struct SMSInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt, order: .reverse) private var accounts: [Account]

    @State private var searchText = ""
    @State private var isShowingGuide = false
    @State private var isShowingActions = false
    @State private var shareItem: ShareItem?
    @State private var exportError: String?
    @State private var groupToDelete: AccountGroup?
    @State private var menuAnchor: CGRect = .zero

    /// 右上角操作卡片的宽度。
    private let actionsMenuWidth: CGFloat = 220

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("凭证存储")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索账号、手机号或短信"
                )
                .toolbar { toolbarContent }
        }
        .onPreferenceChange(MenuAnchorKey.self) { menuAnchor = $0 }
        .overlay {
            if isShowingActions {
                actionsMenu
            }
        }
        .animation(.easeOut(duration: 0.16), value: isShowingActions)
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
                Section {
                    summaryCard
                }

                Section {
                    ForEach(displayedGroups) { group in
                        NavigationLink {
                            AccountGroupDetailView(group: group)
                        } label: {
                            AccountGroupRowView(group: group)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                groupToDelete = group
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(18)
            .contentMargins(.top, 12.5, for: .scrollContent)
        }
    }

    /// 顶部概览：默默记下的账号与手机号总量。
    private var summaryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("已默默记下")
                    .font(.system(size: 15, weight: .medium))
                Text("\(accounts.count) 个账号 · \(phoneTotal) 个手机号")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    /// 去重后的注册手机号数量。
    private var phoneTotal: Int {
        Set(accounts.map(\.phoneNumber).filter { !$0.isEmpty }).count
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    isShowingActions = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: MenuAnchorKey.self,
                                value: proxy.frame(in: .global)
                            )
                        }
                    )
            }
            .buttonStyle(.plain)
        }
    }

    /// 右上角操作卡片：贴着按钮下方展开，无箭头。
    private var actionsMenu: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            let cardX = (menuAnchor == .zero ? proxy.size.width - 16 : menuAnchor.maxX)
                - actionsMenuWidth - origin.x
            let cardY = (menuAnchor == .zero ? 104 : menuAnchor.maxY + 6) - origin.y

            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isShowingActions = false
                        }
                    }

                ActionsMenuCard(width: actionsMenuWidth) {
                    ActionMenuRow(icon: "lightbulb", title: "配置步骤") {
                        dismissThen { isShowingGuide = true }
                    }

                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)

                    Text("导出")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    ActionMenuRow(icon: "tablecells", title: "账号清单") {
                        dismissThen { export(kind: .accounts) }
                    }
                    ActionMenuRow(icon: "doc.text", title: "全部短信") {
                        dismissThen { export(kind: .messages) }
                    }
                }
                .offset(x: max(12, cardX), y: cardY)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
    }

    /// 关闭弹层后再执行动作，避免弹层与后续页面切换打架。
    private func dismissThen(_ action: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.15)) {
            isShowingActions = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: action)
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

    /// 该账号下所有注册手机号（去空、去重）。
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

// MARK: - 操作卡片

/// 菜单按钮在屏幕坐标系中的位置，用于把操作卡片贴到按钮下方。
struct MenuAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

/// 操作卡片容器：纯白底、大圆角、柔和阴影。
struct ActionsMenuCard<Content: View>: View {
    let width: CGFloat
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.vertical, 8)
        .frame(width: width)
        .background(Color(.systemBackground), in: shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.18), radius: 30, y: 14)
    }
}

/// 操作卡片中的一行：文字在左、图标在右。
struct ActionMenuRow: View {
    let icon: String
    let title: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 17))

                Spacer(minLength: 0)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 22)
            }
            .foregroundStyle(isDestructive ? Color.red : Color.primary)
            .padding(.horizontal, 16)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowButtonStyle())
    }
}

/// 按下时轻微加深，反馈更接近系统菜单。
struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.primary.opacity(configuration.isPressed ? 0.06 : 0))
    }
}

// MARK: - 主列表行（按账号名聚合）

/// 聚合行：品牌图标 + 账号名 + 注册手机号（次级灰字，同行展示）。
struct AccountGroupRowView: View {
    let group: AccountGroup

    var body: some View {
        HStack(spacing: 12) {
            MerchantIconView(name: group.name, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)

                Text(group.phones.isEmpty ? "未填写手机号" : group.phones.joined(separator: "、"))
                    .font(.system(size: 14))
                    .foregroundStyle(group.phones.isEmpty ? .tertiary : .secondary)
                    .lineLimit(1)
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
        List {
            Section {
                HStack(spacing: 14) {
                    MerchantIconView(name: group.name, size: 50)
                        .shadow(color: Color.black.opacity(0.10), radius: 6, y: 2)

                    Text(group.name)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .listRowBackground(
                    LinearGradient(
                        colors: [brandTint.opacity(0.14), Color(.secondarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }

            Section {
                ForEach(group.accounts) { account in
                    NavigationLink {
                        AccountDetailView(account: account)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "number")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)

                            Text(account.phoneNumber.isEmpty ? "未填写手机号" : account.phoneNumber)
                                .font(.system(size: 17, weight: .medium, design: .monospaced))
                                .foregroundStyle(account.phoneNumber.isEmpty ? Color.secondary : Color.primary)
                        }
                        .padding(.vertical, 12)
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
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
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

    /// 品牌色，用于顶部卡片的淡色底。
    private var brandTint: Color {
        MerchantIcon.brand(for: group.name)?.color ?? .accentColor
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
