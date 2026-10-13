//
//  VideoPlayerView.swift
//  BiliBili
//
//  Video player & detail page. Pure playback, NO danmaku.
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let video: Video

    @State private var player: AVPlayer?
    @State private var comments: [Comment] = []
    @State private var commentText: String = ""
    @State private var isLiked: Bool = false
    @State private var isFavorited: Bool = false
    @State private var showFullScreen: Bool = false
    @State private var didWriteHistory: Bool = false
    @State private var selectedTab: Int = 0 // 0 = 简介, 1 = 评论
    @State private var isBuffering = false
    @State private var showDescFull = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Player
                    playerSection
                        .frame(height: 220)

                    // Tabs: 简介 / 评论
                    HStack(spacing: 24) {
                        tabButton(title: "简介", index: 0)
                        tabButton(title: "评论 \(comments.count)", index: 1)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    if selectedTab == 0 {
                        introSection
                    } else {
                        commentsSection
                    }
                }
            }
            .background(biliBackgroundGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFullScreen.toggle() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .onAppear {
            setupPlayer()
            loadComments()
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let player = player {
                FullScreenPlayer(player: player)
            }
        }
    }

    // MARK: - Tabs

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == index ? .bold : .regular)
                    .foregroundStyle(selectedTab == index ? Color.biliBlue : .secondary)
                Capsule()
                    .fill(selectedTab == index ? Color.biliBlue : Color.clear)
                    .frame(height: 3)
            }
            .frame(width: 60)
        }
    }

    // MARK: - Player section

    @ViewBuilder
    private var playerSection: some View {
        ZStack {
            Color.black
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                        writeHistoryOnce()
                    }
            } else {
                VStack(spacing: 8) {
                    if isBuffering {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("视频加载中...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        // B站 TV logo placeholder
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            // "B站官方播放器(无弹幕)" pill — top right
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "tv.fill")
                            .font(.caption2)
                        Text("B站官方播放器(无弹幕)")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.biliBlue)
                    .clipShape(Capsule())
                    .padding(12)
                }
                Spacer()
            }
        }
    }

    // MARK: - Intro section

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(video.title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
                .padding(.horizontal)
                .padding(.top, 8)

            // Stats row
            HStack(spacing: 12) {
                Text("\(video.viewsText) 播放")
                Text(video.publishTime)
                Text(video.id)
                    .foregroundColor(.biliBlue)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)

            Divider().padding(.horizontal)

            // UP主 info
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: video.upAvatar)) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(video.upName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(video.viewsText) 粉丝")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    // follow action (mock)
                } label: {
                    Text("已关注")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)

            // Description box
            if !video.desc.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(showDescFull ? nil : 2)
                    Button {
                        showDescFull.toggle()
                    } label: {
                        Text(showDescFull ? "收起简介" : "展开简介")
                            .font(.caption)
                            .foregroundColor(.biliBlue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.biliCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            Divider().padding(.horizontal)

            // Interaction bar
            HStack(spacing: 0) {
                interactionButton(icon: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                                  count: video.likes + (isLiked ? 1 : 0),
                                  label: isLiked ? "已赞" : "点赞",
                                  active: isLiked) { isLiked.toggle() }
                interactionButton(icon: "hand.thumbsdown", count: nil, label: "不喜欢", active: false) {}
                interactionButton(icon: "dollarsign.circle", count: video.coins, label: "投币", active: false) {}
                interactionButton(icon: isFavorited ? "star.fill" : "star",
                                  count: video.favorites + (isFavorited ? 1 : 0),
                                  label: isFavorited ? "已藏" : "收藏",
                                  active: isFavorited) { isFavorited.toggle() }
                interactionButton(icon: "arrowshape.turn.up.right.fill", count: video.shares, label: "分享", active: false) {}
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider().padding(.horizontal)

            // Tags
            HStack(spacing: 8) {
                ForEach(["#魔术", "#奇迹", "#杂谈", "#娱乐"], id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .foregroundColor(.biliBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.biliBlue.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Comments section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Comment input
            HStack {
                TextField("发一条友善的评论...", text: $commentText)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button {
                    sendComment()
                } label: {
                    Text("发送")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.biliBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            ForEach(comments) { c in
                CommentRow(comment: c)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                Divider().padding(.leading, 52)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Player setup (optimized for fast start)

    private func setupPlayer() {
        isBuffering = true
        // Prefetch stream URL; once we have it, build an AVPlayerItem tuned for fast start.
        BiliAPI.shared.streamURL(for: video) { url in
            DispatchQueue.main.async {
                isBuffering = false
                guard let url = url else { return }
                let headers = [
                    "Referer": "https://www.bilibili.com/",
                    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
                ]
                let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                let item = AVPlayerItem(asset: asset)
                // Reduce initial buffering wait and pre-buffer ahead for snappy playback
                item.preferredForwardBufferDuration = 5.0
                if #available(iOS 16.0, *) {
                    item.preferredPeakBitRate = 2_000_000
                }
                let p = AVPlayer(playerItem: item)
                p.automaticallyWaitsToMinimizeStalling = false
                p.rate = 1.0
                self.player = p
                // Start loading immediately
                p.play()
                writeHistoryOnce()
            }
        }
    }

    private func writeHistoryOnce() {
        guard !didWriteHistory else { return }
        didWriteHistory = true
        store.addHistory(video)
    }

    // MARK: - Comments

    private func loadComments() {
        BiliAPI.shared.fetchComments(bvid: video.id) { c in
            DispatchQueue.main.async { comments = c }
        }
    }

    private func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let new = Comment(user: store.currentUser?.name ?? "我",
                          avatar: store.currentUser?.avatar ?? "https://i.pravatar.cc/100?img=99",
                          content: text, likes: 0, time: "刚刚")
        comments.insert(new, at: 0)
        commentText = ""
    }

    // MARK: - Helpers

    private func interactionButton(icon: String, count: Int?, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(active ? Color.biliBlue : .primary)
                HStack(spacing: 2) {
                    if let count = count {
                        Text(count > 10000 ? String(format: "%.1f万", Double(count)/10000) : "\(count)")
                    } else {
                        Text(label)
                    }
                }
                .font(.caption2)
                .foregroundStyle(active ? Color.biliBlue : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Comment row

struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: comment.avatar)) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                } else {
                    Circle().fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(comment.user)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(comment.content)
                    .font(.subheadline)
                HStack(spacing: 12) {
                    Text(comment.time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 3) {
                        Image(systemName: "hand.thumbsup")
                            .font(.caption2)
                        Text("\(comment.likes)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Full screen player

struct FullScreenPlayer: View {
    let player: AVPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: player)
                .onAppear { player.play() }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
    }
}
