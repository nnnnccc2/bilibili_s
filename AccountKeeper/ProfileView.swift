//
//  ProfileView.swift
//  BiliBili
//
//  My page: user info, watch history, filter settings entry, stats
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @Binding var showingSearch: Bool
    @State private var showingLogin = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var selectedVideo: Video?
    @State private var showingLogoutAlert = false
    @State private var showingAbout = false
    @State private var remoteHistory: [HistoryItem] = []
    @State private var isLoadingHistory = false

    private var displayHistory: [HistoryItem] {
        store.currentUser != nil ? remoteHistory : store.history
    }

    private var totalBlocked: Int { store.settings.stats.totalBlocked }

    var body: some View {
        NavigationStack {
            ZStack {
                biliBackgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("个人中心")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
                            Text("极简第三方客户端 · 纯净播放与账号管理")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // User card (includes watch history + favorites)
                        userCard
                            .padding(.horizontal, 16)

                        // Purification dashboard
                        purificationDashboard
                            .padding(.horizontal, 16)

                        // Filter config center entry
                        filterConfigEntry
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundStyle(.biliBlue)
                            .padding(8)
                            .background(Circle().fill(.ultraThinMaterial).opacity(0.9))
                    }
                }
            }
            .sheet(isPresented: $showingLogin) {
                LoginView().environmentObject(store)
            }
            .sheet(isPresented: $showingSettings) {
                FilterSettingsView().environmentObject(store)
            }
            .sheet(item: $selectedVideo) { video in
                VideoPlayerView(video: video).environmentObject(store)
            }
            .alert("退出登录", isPresented: $showingLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) {
                    store.logout()
                    remoteHistory.removeAll()
                }
            } message: {
                Text("确定要退出当前账号吗？")
            }
            .sheet(isPresented: $showingHistory) {
                historySheet
            }
            .sheet(isPresented: $showingAbout) {
                SettingsView()
            }
        }
        .onAppear {
            refreshProfile()
        }
        .onChange(of: store.currentUser) { _, _ in
            refreshProfile()
        }
    }

    private func refreshProfile() {
        guard store.currentUser != nil else { return }
        loadRemoteHistory()
    }

    private func loadRemoteHistory() {
        isLoadingHistory = true
        BiliAPI.shared.fetchHistory { items in
            DispatchQueue.main.async {
                remoteHistory = items
                isLoadingHistory = false
            }
        }
    }

    // MARK: - User card

    @ViewBuilder
    private var userCard: some View {
        if let user = store.currentUser {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    if !user.avatar.isEmpty, let url = URL(string: user.avatar) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                            } else {
                                Circle().fill(Color.biliBlue.opacity(0.3))
                            }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.biliBlue.opacity(0.2))
                                .frame(width: 64, height: 64)
                            Text(String(user.name.prefix(1)))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.biliBlue)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(user.name)
                                .font(.title3)
                                .fontWeight(.bold)
                            if user.isVip {
                                Text("年度大会员")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(red: 0.95, green: 0.3, blue: 0.4))
                                    .clipShape(Capsule())
                            }
                        }
                        Text("硬币: \(user.coins) · LV\(user.level)\(user.maskedPhone.isEmpty ? "" : " · " + user.maskedPhone)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showingLogoutAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("退出")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                    }
                }

                // Watch history + favorites
                HStack(spacing: 0) {
                    historyStat
                    Divider()
                        .frame(height: 36)
                    favoritesStat
                }
            }
            .padding(16)
            .background(Color.biliCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.biliBorder, lineWidth: 1)
            )
        } else {
            Button {
                showingLogin = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.biliBlue.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(Color.biliBlue)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("点击登录")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text("登录后可同步观看历史与收藏")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(Color.biliCard)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.biliBorder, lineWidth: 1)
                )
            }
        }
    }

    private var historyStat: some View {
        Button {
            showingHistory = true
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.biliBlue)
                    Text("观看历史")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("(\(displayHistory.count))")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Text("真实记录随看随存")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var favoritesStat: some View {
        Button {
            // favorites (mock)
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark")
                        .foregroundStyle(.orange)
                    Text("我的收藏")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("(8)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Text("精选优质内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Purification dashboard

    private var purificationDashboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(.biliBlue)
                Text("全站低质视频净化看板")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    HStack(spacing: 2) {
                        Text("管理过滤规则")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.biliBlue)
                }
            }

            // Big number card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("全站累计净化屏蔽")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(totalBlocked)")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.biliBlue)
                        Text("条低质视频")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.biliBlue.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.title)
                        .foregroundStyle(.biliBlue)
                }
            }
            .padding(16)
            .background(Color.biliBlue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Filter type breakdown
            VStack(spacing: 0) {
                filterRow(icon: "exclamationmark.circle.fill", iconColor: .red,
                          title: "标题党与惊悚引导词", count: store.settings.stats.byClickbait)
                filterRow(icon: "clock.fill", iconColor: .orange,
                          title: "视频时长限制屏蔽", count: store.settings.stats.byDuration)
                filterRow(icon: "character.book.closed.fill", iconColor: .purple,
                          title: "博主/标题含日文字符",
                          count: store.settings.stats.byJapaneseTitle + store.settings.stats.byJapaneseUP)
                filterRow(icon: "hand.raised.fill", iconColor: .green,
                          title: "侮辱贬低词库拦截", count: store.settings.stats.byInsultWord)
            }
            .background(Color.biliCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.biliBorder, lineWidth: 1)
        )
    }

    private func filterRow(icon: String, iconColor: Color, title: String, count: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count) 次")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 12)
            Divider().padding(.leading, 32)
        }
    }

    // MARK: - History sheet

    private var historySheet: some View {
        NavigationStack {
            ZStack {
                biliBackgroundGradient.ignoresSafeArea()
                Group {
                    if isLoadingHistory {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if displayHistory.isEmpty {
                        ContentUnavailableView("暂无观看历史", systemImage: "clock")
                    } else {
                        List {
                            ForEach(displayHistory) { item in
                                Button {
                                    playHistoryItem(item)
                                    showingHistory = false
                                } label: {
                                    HStack(spacing: 10) {
                                        AsyncImage(url: URL(string: item.cover)) { phase in
                                            if let img = phase.image {
                                                img.resizable().aspectRatio(contentMode: .fill)
                                            } else {
                                                Rectangle().fill(Color.gray.opacity(0.2))
                                            }
                                        }
                                        .frame(width: 80, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.subheadline)
                                                .lineLimit(2)
                                                .foregroundStyle(.primary)
                                            Text(item.upName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("观看历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showingHistory = false }
                        .foregroundStyle(.biliBlue)
                }
            }
        }
    }

    private func playHistoryItem(_ item: HistoryItem) {
        BiliAPI.shared.fetchVideoDetail(bvid: item.videoId) { video in
            DispatchQueue.main.async {
                if let video = video {
                    selectedVideo = video
                }
            }
        }
    }

    // MARK: - Filter config entry

    private var filterConfigEntry: some View {
        Button {
            showingSettings = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(.biliBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text("过滤与词库配置中心")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text("16档时长多选屏蔽、日文过滤、侮辱词库管理")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.biliBorder, lineWidth: 1)
            )
        }
    }
}
