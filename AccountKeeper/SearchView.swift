//
//  SearchView.swift
//  BiliBili
//
//  Search page with content type tabs and duration filters
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
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

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("搜索视频、番剧、UP主", text: $keyword)
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

                // Content type tabs
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

                // Duration filter chips (search-specific)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(FilterSettings.searchDurationOptions.enumerated()), id: \.offset) { index, opt in
                            Button {
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
                    // Hot search suggestions (real-time from Bilibili)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("大家都在搜")
                            .font(.headline)
                            .padding(.horizontal)
                        if isLoadingKeywords && hotKeywords.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else if hotKeywords.isEmpty {
                            Text("暂无热搜数据")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(hotKeywords, id: \.self) { kw in
                                    Button {
                                        keyword = kw
                                        performSearch()
                                    } label: {
                                        Text(kw)
                                            .font(.subheadline)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(Color(.secondarySystemBackground))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                    .padding(.top)
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "没有匹配的内容",
                        systemImage: "magnifyingglass",
                        description: Text("部分结果可能已被过滤规则净化，试试其他关键词")
                    )
                } else {
                    // Result count + filtered banner
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

                    ScrollView {
                        if searchType == .user {
                            userList
                        } else {
                            // 视频/番剧/直播：双列卡片网格
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
                                            if video.id == results.last?.id, hasMore, !isLoadingMore {
                                                loadMore()
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        }

                        if isLoadingMore {
                            ProgressView().padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("搜索")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
            .fullScreenCover(item: $selectedVideo) { video in
                VideoPlayerView(video: video)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingUPSpace) {
                if selectedUPMid > 0 {
                    UPSpaceView(mid: selectedUPMid, initialName: selectedUPName)
                        .environmentObject(store)
                }
            }
            .onAppear { loadHotKeywords() }
        }
    }

    // MARK: - User search results (extracted to reduce type-check complexity)
    private var userList: some View {
        LazyVStack(spacing: 10) {
            ForEach(results) { user in
                userRow(user)
                    .onAppear {
                        if user.id == results.last?.id, hasMore, !isLoadingMore {
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
            HStack(spacing: 12) {
                CachedAsyncImage(
                    url: URL(string: BiliAPI.coverThumb(user.upAvatar, width: 120)),
                    targetSize: CGSize(width: 56, height: 56)
                ) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !user.desc.isEmpty {
                        Text(user.desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(Color.biliBlue)
                        Text("\(user.viewsText) 粉丝")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.biliCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

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
        // Reset duration filter display to match current setting
        if let cur = store.settings.searchMinDurationSeconds {
            if let idx = FilterSettings.searchDurationOptions.firstIndex(where: { $0.seconds == cur }) {
                selectedDurationIndex = idx
            }
        } else {
            selectedDurationIndex = 0
        }
        let minDur = store.settings.searchMinDurationSeconds
        // Fetch 2 pages in parallel for more results (Bilibili caps at 50/page).
        // The API request carries the server-side duration bucket (for 1h+ filters)
        // so we get many more matching videos than client-side filtering alone.
        var page1: [Video] = []
        var page2: [Video] = []
        let group = DispatchGroup()
        group.enter()
        BiliAPI.shared.search(keyword: keyword, type: searchType, page: 1, minDurationSeconds: minDur) { raw in
            DispatchQueue.main.async {
                page1 = store.applySearchFilter(raw)
            }
            group.leave()
        }
        group.enter()
        BiliAPI.shared.search(keyword: keyword, type: searchType, page: 2, minDurationSeconds: minDur) { raw in
            DispatchQueue.main.async {
                page2 = store.applySearchFilter(raw)
            }
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
        let minDur = store.settings.searchMinDurationSeconds
        BiliAPI.shared.search(keyword: keyword, type: searchType, page: page, minDurationSeconds: minDur) { raw in
            DispatchQueue.main.async {
                let filtered = store.applySearchFilter(raw)
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
