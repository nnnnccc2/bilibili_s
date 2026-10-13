//
//  HomeView.swift
//  BiliBili
//
//  Home page with category tabs and filtered video feed
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @Binding var showingSearch: Bool
    @State private var category: HomeCategory = .recommend
    @State private var videos: [Video] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var page = 1
    @State private var hasMore = true
    @State private var selectedVideo: Video?
    @State private var lastRefreshDate = Date.distantPast
    @State private var selectedUPMid: Int = 0
    @State private var selectedUPName: String = ""
    @State private var showingUPSpace = false

    var body: some View {
        NavigationStack {
            ZStack {
                biliBackgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top category tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(HomeCategory.allCases) { cat in
                                Button {
                                    category = cat
                                    page = 1
                                    hasMore = true
                                    loadVideos(force: true)
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(cat.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(category == cat ? .bold : .regular)
                                            .foregroundStyle(category == cat ? Color.biliBlue : .secondary)
                                        if category == cat {
                                            Capsule()
                                                .fill(Color.biliBlue)
                                                .frame(width: 20, height: 3)
                                        } else {
                                            Capsule()
                                                .fill(Color.clear)
                                                .frame(width: 20, height: 3)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // Filtered banner
                    if store.settings.showFilteredBanner && store.lastBlockedCount > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(.biliBlue)
                            Text("已为你净化 \(store.lastBlockedCount) 条低质内容")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                store.lastBlockedCount = 0
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color.biliBlue.opacity(0.08))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Video grid
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if videos.isEmpty {
                        ContentUnavailableView(
                            "暂无内容",
                            systemImage: "tray",
                            description: Text("试试切换其他分类或调整过滤规则")
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(videos) { video in
                                    VideoCardView(video: video) {
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
                                            if video.id == videos.last?.id, hasMore, !isLoadingMore {
                                                loadMore()
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .padding(.bottom, 20)

                            if isLoadingMore {
                                ProgressView().padding(.vertical, 12)
                            }
                        }
                        .refreshable {
                            await loadVideosAsync(force: true)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("BiliBili")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.biliBlue)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundColor(.biliBlue)
                            .padding(8)
                            .background(Circle().fill(.ultraThinMaterial).opacity(0.9))
                    }
                }
            }
            .sheet(item: $selectedVideo) { video in
                VideoPlayerView(video: video)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingUPSpace) {
                if selectedUPMid > 0 {
                    UPSpaceView(mid: selectedUPMid, initialName: selectedUPName)
                        .environmentObject(store)
                }
            }
        }
        .onAppear {
            // Refresh if never loaded or stale (>30s)
            if videos.isEmpty || Date().timeIntervalSince(lastRefreshDate) > 30 {
                loadVideos(force: true)
            }
        }
    }

    private func loadVideos(force: Bool = false) {
        isLoading = true
        page = 1
        hasMore = true
        BiliAPI.shared.fetchHome(category: category, page: page) { raw in
            let filtered = store.applyFilter(raw)
            DispatchQueue.main.async {
                videos = filtered
                isLoading = false
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
            let filtered = store.applyFilter(raw)
            DispatchQueue.main.async {
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
            BiliAPI.shared.fetchHome(category: category, page: 1) { raw in
                let filtered = store.applyFilter(raw)
                DispatchQueue.main.async {
                    videos = filtered
                    isLoading = false
                    lastRefreshDate = Date()
                    page = 2
                    hasMore = !filtered.isEmpty
                    continuation.resume()
                }
            }
        }
    }
}
