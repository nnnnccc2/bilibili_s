//
//  HomeView.swift
//  BiliBili
//
//  Home page with pill category tabs and filtered video feed
//  (matches the reference design: hero backdrop, translucent content board)
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @Binding var showingSearch: Bool
    @State private var category: HomeCategory = .recommend
    @State private var videos: [Video] = []
    @State private var rawVideos: [Video] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var isLoadingMore = false
    @State private var page = 1
    @State private var hasMore = true
    @State private var selectedVideo: Video?
    @State private var lastRefreshDate = Date.distantPast
    @State private var selectedUPMid: Int = 0
    @State private var selectedUPName: String = ""
    @State private var showingUPSpace = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.biliHero.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                contentBoard
            }
        }
        .overlay {
            if let video = selectedVideo {
                VideoPlayerView(video: video, onDismiss: { dismissImmersive({ selectedVideo = nil }) })
                    .environmentObject(store)
                    .ignoresSafeArea()
                    .immersive(backdrop: .black)
                    .id(video.id)
                    .zIndex(10)
            }
        }
        .overlay {
            if showingUPSpace, selectedUPMid > 0 {
                UPSpaceView(mid: selectedUPMid, initialName: selectedUPName, onDismiss: { dismissImmersive({ showingUPSpace = false }) })
                    .environmentObject(store)
                    .immersive()
                    .zIndex(20)
            }
        }
        .onAppear {
            // Refresh if never loaded or stale (>30s)
            if videos.isEmpty || Date().timeIntervalSince(lastRefreshDate) > 30 {
                loadVideos(force: true)
            }
        }
        .onChange(of: store.settings) { _, _ in
            // Re-apply filter live when the user toggles a rule.
            // countStats:false avoids double-counting already-counted blocks.
            videos = store.applyFilter(rawVideos, countStats: false)
        }
    }

    // MARK: - Header (pill tabs + app badge)
    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(HomeCategory.allCases) { cat in
                    Button {
                        guard category != cat else { return }
                        category = cat
                        page = 1
                        hasMore = true
                        loadVideos(force: true)
                    } label: {
                        Text(cat.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(category == cat ? Color.white : Color.biliTabText)
                            .frame(minWidth: 56)
                            .padding(.vertical, 8)
                            .background(category == cat ? Color.biliBlue : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.8))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255))
                Text("BiliBili 直连")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.biliSubtext)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Content board (rounded translucent surface over the hero)
    private var contentBoard: some View {
        VStack(spacing: 0) {
            // Filtered banner
            if store.settings.showFilteredBanner && store.lastBlockedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.biliBlue)
                    Text("已为你净化 \(store.lastBlockedCount) 条低质内容 · Tag 补全 \(store.feedDiagnostics.withTags)/\(store.feedDiagnostics.total)")
                        .font(.caption)
                        .foregroundStyle(Color.biliSubtext)
                    Spacer()
                    Button {
                        store.lastBlockedCount = 0
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.biliBlue.opacity(0.08))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 数据诊断条：确认元数据补拉是否成功（带 tag / 带分区 的条数）。
            // Tag 全为 0 说明补拉失败，此时任何 Tag 规则都不可能命中。
            if store.feedDiagnostics.total > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.secondary)
                    Text("数据诊断v4 共\(store.feedDiagnostics.total)条 · 带tag \(store.feedDiagnostics.withTags) · 带分区 \(store.feedDiagnostics.withTid) · Tag拦截 \(store.lastTagBlockedCount)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

                if !store.feedDiagnostics.note.isEmpty {
                    Text(store.feedDiagnostics.note)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }

                Text(store.activeFilterSummary)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }

            if isLoading || !hasLoadedOnce {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if videos.isEmpty {
                ContentUnavailableView(
                    "暂无内容",
                    systemImage: "tray",
                    description: Text("试试切换其他分类或调整过滤规则")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(videos) { video in
                            VideoCardView(video: video, onBlockUP: { mid, _ in
                                store.blockUP(mid: mid)
                            }) {
                                if video.upMid > 0 {
                                    selectedUPMid = video.upMid
                                    selectedUPName = video.upName
                                    showingUPSpace = true
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedVideo = video
                            }
                            .onAppear {
                                guard hasMore, !isLoadingMore else { return }
                                // Pre-load when within the last 4 items so
                                // scrolling stays continuous — no stop-wait-load
                                // hitch at the very bottom.
                                if let idx = videos.firstIndex(where: { $0.id == video.id }),
                                   idx >= videos.count - 4 {
                                    loadMore()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                    if isLoadingMore {
                        ProgressView().padding(.vertical, 12)
                    }
                }
                .refreshable {
                    await loadVideosAsync(force: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.biliBackground)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
    }

    /// Load the feed from the current `page`. `page` is the *next* batch to
    /// fetch, so it is not reset here — that is what lets a pull-to-refresh move
    /// forward to fresh content (page 1 is always the same items for 热门/直播,
    /// which is why refreshing used to show nothing new).
    private func loadVideos(force: Bool = false) {
        isLoading = true
        hasMore = true
        BiliAPI.shared.fetchHome(category: category, page: page) { raw in
            DispatchQueue.main.async {
                rawVideos = raw
                store.feedDiagnostics = AppStore.FeedDiagnostics(
                    total: raw.count,
                    withTags: raw.filter { !$0.tags.isEmpty }.count,
                    withTid: raw.filter { $0.tid != 0 }.count,
                    note: BiliAPI.shared.lastEnrichReport.note
                )
                let engine = store.engine
                store.lastTagBlockedCount = raw.filter { engine.shouldBlock($0) == .tagBlocked }.count
                let filtered = store.applyFilter(raw)
                videos = filtered
                isLoading = false
                hasLoadedOnce = true
                lastRefreshDate = Date()
                if filtered.isEmpty {
                    hasMore = false
                } else {
                    page += 1
                }
            }
        }
    }

    private func loadMore() {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        BiliAPI.shared.fetchHome(category: category, page: page) { raw in
            DispatchQueue.main.async {
                rawVideos.append(contentsOf: raw)
                let filtered = store.applyFilter(raw)
                if filtered.isEmpty {
                    hasMore = false
                } else {
                    videos.append(contentsOf: filtered)
                    page += 1
                }
                isLoadingMore = false
            }
        }
    }

    @Sendable
    private func loadVideosAsync(force: Bool = false) async {
        await withCheckedContinuation { continuation in
            // Pull-to-refresh fetches the *next* page (not page 1) so the list
            // visibly changes, then replaces the feed with that fresh batch.
            BiliAPI.shared.fetchHome(category: category, page: page) { raw in
                DispatchQueue.main.async {
                    let filtered = store.applyFilter(raw)
                    if !filtered.isEmpty {
                        rawVideos = raw
                        videos = filtered
                        page += 1
                        hasMore = true
                    } else {
                        // Reached the end of the feed — keep the current list
                        // instead of blanking the screen on a refresh.
                        hasMore = false
                    }
                    isLoading = false
                    hasLoadedOnce = true
                    lastRefreshDate = Date()
                    continuation.resume()
                }
            }
        }
    }
}
