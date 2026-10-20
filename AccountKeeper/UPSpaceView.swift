//
//  UPSpaceView.swift
//  BiliBili
//
//  UP主个人空间：资料、关注按钮、视频列表。
//  overlay 呈现，无粘滞动画。
//

import SwiftUI

struct UPSpaceView: View {
    @EnvironmentObject var store: AppStore

    let mid: Int
    let initialName: String
    var onDismiss: (() -> Void)? = nil

    @State private var info: UPSpaceInfo?
    @State private var videos: [Video] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var page = 1
    @State private var hasMore = true
    @State private var isFollowing = false
    @State private var isFollowBusy = false
    @State private var selectedVideo: Video?
    @State private var loadError: String? = nil

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerSection
                statsSection
                videoGridSection
            }
        }
        .background(biliBackgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(info?.name ?? initialName)
                    .font(.headline)
                    .lineLimit(1)
            }
        }
        .onAppear {
            if info == nil {
                loadInfo()
                loadVideos(reset: true)
            }
        }
        // 播放器：系统全屏模态（原生滑入 / 可下拉返回）。.playerOverlay(for: $selectedVideo, store: store)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                CachedAsyncImage(
                    url: URL(string: BiliAPI.coverThumb(info?.avatar ?? "", width: 128)),
                    targetSize: CGSize(width: 72, height: 72)
                ) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(info?.name ?? initialName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        if let level = info?.level, level > 0 {
                            Text("LV\(level)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.biliBlue)
                                .clipShape(Capsule())
                        }
                    }
                    Text(info?.sign ?? "这个人很懒，什么都没留下")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Button {
                toggleFollow()
            } label: {
                HStack(spacing: 6) {
                    if isFollowBusy {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: isFollowing ? "checkmark" : "plus")
                    }
                    Text(isFollowing ? "已关注" : "关注")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(isFollowing ? Color.secondary : .white)
                .background(isFollowing ? Color(.systemGray5) : Color.biliBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isFollowBusy)
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
        .background(Color.white.opacity(0.6))
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem(value: info?.following ?? 0, label: "关注")
            statItem(value: info?.fans ?? 0, label: "粉丝")
            statItem(value: info?.likes ?? 0, label: "获赞")
            statItem(value: info?.archiveCount ?? videos.count, label: "视频")
        }
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.4))
        .padding(.bottom, 8)
    }

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value > 10000 ? String(format: "%.1f万", Double(value)/10000) : "\(value)")
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Video grid

    @ViewBuilder
    private var videoGridSection: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let loadError = loadError {
            VStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("加载失败")
                    .font(.headline)
                Text("网络异常或被风控拦截")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("点击重试") {
                    loadError = nil
                    loadVideos(reset: true)
                }
                .buttonStyle(.borderedProminent)
                .font(.subheadline)
                .tint(.biliBlue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if videos.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "video.slash")
                    .font(.system(size: 30))
                    .foregroundStyle(.tertiary)
                Text("暂无视频")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(videos) { video in
                    Button {
                        selectedVideo = video
                    } label: {
                        VideoCardView(video: video)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableCardStyle())
                    .transition(.cardEnter)
                    .onAppear {
                        if video.id == videos.last?.id, hasMore, !isLoadingMore {
                            loadVideos(reset: false)
                        }
                    }
                }
            }
            .animation(MiniBiliAnimation.cardEnter, value: videos.count)
            .padding(.horizontal, 8)
            .padding(.bottom, 20)

            if isLoadingMore {
                ProgressView().padding(.vertical, 12)
            }
        }
    }

    // MARK: - Actions

    private func loadInfo() {
        BiliAPI.shared.fetchUPSpaceInfo(mid: mid) { info in
            DispatchQueue.main.async { self.info = info }
        }
        if store.currentUser != nil {
            BiliAPI.shared.checkRelation(mid: mid) { following in
                DispatchQueue.main.async { self.isFollowing = following }
            }
        }
    }

    private func loadVideos(reset: Bool) {
        if reset {
            page = 1
            hasMore = true
            videos = []
            loadError = nil
        }
        guard hasMore else { return }
        if reset { isLoading = true } else { isLoadingMore = true }

        BiliAPI.shared.fetchUPVideos(mid: mid, page: page) { newVideos, total, error in
            DispatchQueue.main.async {
                if reset {
                    videos = newVideos
                } else {
                    videos.append(contentsOf: newVideos)
                }
                if let error = error {
                    // Only treat as hard error when the grid would be empty AND
                    // both endpoints failed. A subsequent "load more" hitting an
                    // error should just stop pagination, not wipe the list.
                    if reset && videos.isEmpty {
                        loadError = error
                    } else {
                        hasMore = false
                    }
                } else {
                    loadError = nil
                    if newVideos.isEmpty || videos.count >= total {
                        hasMore = false
                    } else {
                        page += 1
                    }
                }
                isLoading = false
                isLoadingMore = false
            }
        }
    }

    private func toggleFollow() {
        guard store.currentUser != nil else { return }
        isFollowBusy = true
        let action = isFollowing ? 2 : 1
        BiliAPI.shared.modifyRelation(mid: mid, action: action) { success, _ in
            DispatchQueue.main.async {
                isFollowBusy = false
                if success {
                    isFollowing.toggle()
                }
            }
        }
    }
}
