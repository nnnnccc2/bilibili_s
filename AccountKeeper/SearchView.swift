//
//  SearchView.swift
//  BiliBili
//
//  Search page — overlay presentation, no sticky animation.
//  Only 视频 / 用户 tabs. Hot keywords: 哔哩哔哩热搜 in tiny gray.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var store: AppStore
    @State private var keyword: String = ""
    @State private var searchType: SearchType = .video
    @State private var results: [Video] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var page = 1
    @State private var hasMore = true
    @State private var hasSearched = false
    @State private var selectedDurationIndex: Int = 0
    @State private var selectedVideo: Video?
    @State private var selectedUPMid: Int = 0
    @State private var selectedUPName: String = ""
    @State private var showingUPSpace = false
    @State private var hotKeywords: [String] = []
    @State private var isLoadingKeywords = false

    /// Callback when user taps the cancel button (overlay presentation).
    var onDismiss: (() -> Void)? = nil

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("搜索视频、UP主", text: $keyword)
                            .submitLabel(.search)
                            .onSubmit { performSearch() }
                        if !keyword.isEmpty {
                            Button {
                                keyword = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        performSearch()
                    } label: {
                        Text("搜索")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.biliBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 6)

                // Content type tabs — only 视频 / 用户 now
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SearchType.allCases) { type in
                            Button {
                                searchType = type
                                if hasSearched { performSearch() }
                            } label: {
                                Text(type.rawValue)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(searchType == type ? Color.biliBlue.opacity(0.15) : Color.clear)
                                    .foregroundStyle(searchType == type ? Color.biliBlue : .secondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Duration filter chips. Shown for both video and user search; for
                // user search a tap is simply a no-op (user results carry no
                // duration, so a duration filter is meaningless there).
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(FilterSettings.searchDurationOptions.enumerated()), id: \.offset) { index, opt in
                            Button {
                                guard searchType == .video else { return }
                                selectedDurationIndex = index
                                let seconds = opt.seconds
                                store.settings.searchMinDurationSeconds = seconds
                                if hasSearched { performSearch() }
                            } label: {
                                Text(opt.label)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(selectedDurationIndex == index ? Color.biliBlue : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedDurationIndex == index ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                Divider()

                // Results
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasSearched {
                    hotKeywordsView
                        .padding(.top)
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "没有匹配的内容",
                        systemImage: "magnifyingglass",
                        description: Text(store.lastBlockedCount > 0
                                          ? "结果被过滤规则净化了 \(store.lastBlockedCount) 条，可放宽过滤或更换关键词"
                                          : "试试其他关键词")
                    )
                } else {
                    resultScrollView
                }
            }
            .background(biliBackgroundGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("搜索")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        if let onDismiss = onDismiss { onDismiss() }
                    }
                }
            }
            .onAppear { loadHotKeywords() }
        }
        .overlay {
            if let video = selectedVideo {
                VideoPlayerView(video: video, onDismiss: { dismissImmersive({ selectedVideo = nil }, duration: 0.3) })
                    .environmentObject(store)
                    .ignoresSafeArea()
                    .immersive(fadeIn: false)
                    .id(video.id)
                    .zIndex(10)
            }
        }
        .overlay {
            if showingUPSpace {
                UPSpaceView(mid: selectedUPMid, initialName: selectedUPName, onDismiss: { dismissImmersive({ showingUPSpace = false }, duration: 0.4) })
                    .environmentObject(store)
                    .immersive(duration: 0.42)
                    .zIndex(20)
            }
        }
    }

    // MARK: - Hot keywords (哔哩哔哩热搜, gray and readable, never blue)

    private var hotKeywordsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("哔哩哔哩热搜")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary)
                .padding(.horizontal)
            if isLoadingKeywords && hotKeywords.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if hotKeywords.isEmpty {
                Text("暂无热搜数据")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal)
            } else {
                // Secondary element: plain gray words that wrap loosely at their
                // natural widths (no rigid grid), kept within ~4/7 of the width.
                FlowLayout(spacing: 9) {
                    ForEach(Array(hotKeywords.prefix(8).enumerated()), id: \.offset) { _, kw in
                        Button {
                            keyword = kw
                            performSearch()
                        } label: {
                            Text(kw)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 4.0 / 7.0, alignment: .leading)
                .padding(.leading)
                .transition(.opacity)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Results

    private var resultScrollView: some View {
        ScrollView {
            VStack(spacing: 4) {
                HStack {
                    Text("找到 \(results.count) 个结果")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if store.lastBlockedCount > 0 {
                        Text("· 已净化 \(store.lastBlockedCount) 条")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            if searchType == .user {
                userList
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(results) { video in
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
                                guard hasMore, !isLoadingMore else { return }
                                if let idx = results.firstIndex(where: { $0.id == video.id }),
                                   idx >= results.count - 4 {
                                    loadMore()
                                }
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .animation(.easeOut(duration: 0.2), value: results.count)
            }

            if isLoadingMore {
                ProgressView().padding(.vertical, 12)
            }
        }
    }

    // MARK: - User search results

    private var userList: some View {
        LazyVStack(spacing: 8) {
            ForEach(results) { user in
                userRow(user)
                    .onAppear {
                        guard hasMore, !isLoadingMore else { return }
                        if let idx = results.firstIndex(where: { $0.id == user.id }),
                           idx >= results.count - 4 {
                            loadMore()
                        }
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private func userRow(_ user: Video) -> some View {
        Button {
            if user.upMid > 0 {
                selectedUPMid = user.upMid
                selectedUPName = user.upName
                showingUPSpace = true
            }
        } label: {
            HStack(spacing: 10) {
                CachedAsyncImage(
                    url: URL(string: BiliAPI.coverThumb(user.upAvatar, width: 120)),
                    targetSize: CGSize(width: 44, height: 44)
                ) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !user.desc.isEmpty {
                        Text(user.desc)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("\(user.viewsText) 粉丝")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.biliCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadHotKeywords() {
        guard hotKeywords.isEmpty else { return }
        isLoadingKeywords = true
        BiliAPI.shared.fetchTrendingKeywords(limit: 10) { keywords in
            DispatchQueue.main.async {
                hotKeywords = keywords
                isLoadingKeywords = false
            }
        }
    }

    private func performSearch() {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        hasSearched = true
        page = 1
        hasMore = true
        // Duration filter only applies to video search.
        let isVideoSearch = searchType == .video
        if isVideoSearch, let cur = store.settings.searchMinDurationSeconds {
            if let idx = FilterSettings.searchDurationOptions.firstIndex(where: { $0.seconds == cur }) {
                selectedDurationIndex = idx
            }
        } else if isVideoSearch {
            selectedDurationIndex = 0
        }
        let minDur = isVideoSearch ? store.settings.searchMinDurationSeconds : nil
        var page1: [Video] = []
        var page2: [Video] = []
        let group = DispatchGroup()
        group.enter()
        BiliAPI.shared.search(keyword: keyword, type: searchType, page: 1, minDurationSeconds: minDur) { raw in
            DispatchQueue.main.async { page1 = store.applySearchFilter(raw, applyMinDuration: isVideoSearch) }
            group.leave()
        }
        group.enter()
        BiliAPI.shared.search(keyword: keyword, type: searchType, page: 2, minDurationSeconds: minDur) { raw in
            DispatchQueue.main.async { page2 = store.applySearchFilter(raw, applyMinDuration: isVideoSearch) }
            group.leave()
        }
        group.notify(queue: .main) {
            var combined = page1
            for v in page2 where !combined.contains(where: { $0.id == v.id }) {
                combined.append(v)
            }
            results = combined
            isLoading = false
            page = 3
            hasMore = !combined.isEmpty
        }
    }

    private func loadMore() {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        let isVideoSearch = searchType == .video
        let minDur = isVideoSearch ? store.settings.searchMinDurationSeconds : nil
        BiliAPI.shared.search(keyword: keyword, type: searchType, page: page, minDurationSeconds: minDur) { raw in
            DispatchQueue.main.async {
                let filtered = store.applySearchFilter(raw, applyMinDuration: isVideoSearch)
                if filtered.isEmpty {
                    hasMore = false
                } else {
                    results.append(contentsOf: filtered)
                    page += 1
                }
                isLoadingMore = false
            }
        }
    }
}

// MARK: - Simple flow layout for hot keywords

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for row in rows {
            height += row.height + spacing
        }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for element in row.elements {
                element.subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += element.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var elements: [(subview: LayoutSubview, width: CGFloat)]
        var height: CGFloat
    }

    private func arrangeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var rows: [Row] = []
        var currentRow = Row(elements: [], height: 0)
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width + spacing > maxWidth, !currentRow.elements.isEmpty {
                rows.append(currentRow)
                currentRow = Row(elements: [], height: 0)
                currentWidth = 0
            }
            currentRow.elements.append((subview, size.width))
            currentRow.height = max(currentRow.height, size.height)
            currentWidth += size.width + spacing
        }
        if !currentRow.elements.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }
}
