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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // User info header
                    userHeader

                    // Stats cards
                    statsRow
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // Watch history
                    historySection

                    // Quick actions
                    quickActions
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Spacer(minLength: 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(8)
                            .background(Circle().fill(.ultraThinMaterial).opacity(0.9))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
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

    // MARK: - User header

    @ViewBuilder
    private var userHeader: some View {
        if let user = store.currentUser {
            HStack(spacing: 14) {
                if !user.avatar.isEmpty, let url = URL(string: user.avatar) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            Circle().fill(Color.pink.opacity(0.3))
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.pink.opacity(0.2))
                            .frame(width: 64, height: 64)
                        Text(String(user.name.prefix(1)))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.pink)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(user.name)
                            .font(.title3)
                            .fontWeight(.bold)
                        if user.isVip {
                            Text("大会员")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        Text("LV\(user.level)")
                            .font(.caption)
                            .foregroundStyle(.pink)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.pink.opacity(0.12))
                            .clipShape(Capsule())
                        Text("硬币: \(user.coins)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !user.maskedPhone.isEmpty {
                            Text("· \(user.maskedPhone)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(Color(.systemBackground))
        } else {
            Button {
                showingLogin = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.pink.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(Color.pink)
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
                .background(Color(.systemBackground))
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCard(label: "累计净化", value: "\(store.settings.stats.totalBlocked)", icon: "shield.lefthalf.filled", color: .green)
            statCard(label: "观看历史", value: "\(displayHistory.count)", icon: "clock.arrow.circlepath", color: .blue)
            statCard(label: "屏蔽词库", value: "\(store.settings.customBlockedWords.count + (store.settings.builtInWordsEnabled ? FilterSettings.builtInInsultWords.count : 0))", icon: "hand.raised.fill", color: .red)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - History section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("观看历史")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                Spacer()
                if !displayHistory.isEmpty {
                    Button {
                        if store.currentUser != nil {
                            remoteHistory.removeAll()
                        } else {
                            store.clearHistory()
                        }
                    } label: {
                        Text("清空")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }

            if isLoadingHistory {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if displayHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("暂无观看历史")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(displayHistory.prefix(10)) { item in
                            historyCard(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func historyCard(item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: item.cover)) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 120, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Text(item.title)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
            Text(item.progressText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            playHistoryItem(item)
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

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(spacing: 0) {
            actionRow(icon: "gearshape", title: "过滤与设置", color: .pink) {
                showingSettings = true
            }
            Divider().padding(.leading, 52)
            actionRow(icon: "clock.arrow.circlepath", title: "观看历史", color: .blue) {
                // scroll to history or open full list
            }
            Divider().padding(.leading, 52)
            actionRow(icon: "heart.fill", title: "我的收藏", color: .red) {}
            Divider().padding(.leading, 52)
            actionRow(icon: "info.circle", title: "关于", color: .gray) {
                showingAbout = true
            }
            if store.currentUser != nil {
                Divider().padding(.leading, 52)
                actionRow(icon: "rectangle.portrait.and.arrow.right", title: "退出登录", color: .red) {
                    showingLogoutAlert = true
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func actionRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}
