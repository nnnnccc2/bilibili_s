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
    @State private var isFollowing = false
    @State private var isFollowBusy = false
    @State private var showingUPSpace = false
    @State private var toast: String?
    @State private var aid: Int = 0
    @State private var isSendingComment = false
    @State private var upFans: Int = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Dark background so letterbox areas are black, not white
            Color.black.ignoresSafeArea()

            if showFullScreen {
                // True full-screen: only the player, edge-to-edge
                if let p = player {
                    VideoPlayer(player: p)
                        .ignoresSafeArea()
                        .onAppear { p.play() }
                } else {
                    Color.black.ignoresSafeArea()
                }
                // Top controls overlay
                VStack {
                    HStack {
                        Button { showFullScreen = false } label: {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(12)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Player (16:9, edge-to-edge, no white bar above)
                        playerSection
                            .aspectRatio(16.0/9.0, contentMode: .fit)
                            .frame(maxWidth: .infinity)

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
                .background(Color.biliBackground)
                .scrollIndicators(.hidden)

                // Top controls overlaid on the player
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button { showFullScreen = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
        }
        .onAppear {
            setupPlayer()
            loadComments()
            if video.upMid > 0 {
                BiliAPI.shared.fetchUPSpaceInfo(mid: video.upMid) { info in
                    DispatchQueue.main.async { upFans = info?.fans ?? 0 }
                }
            }
            if store.currentUser != nil, video.upMid > 0 {
                BiliAPI.shared.checkRelation(mid: video.upMid) { following in
                    DispatchQueue.main.async { isFollowing = following }
                }
            }
        }
        .sheet(isPresented: $showingUPSpace) {
            if video.upMid > 0 {
                UPSpaceView(mid: video.upMid, initialName: video.upName)
                    .environmentObject(store)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = toast {
                Text(toast)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { self.toast = nil }
                    }
            }
        }
        .statusBarHidden(showFullScreen)
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

            // UP主 info (tap to open space)
            HStack(spacing: 10) {
                Button {
                    if video.upMid > 0 { showingUPSpace = true }
                } label: {
                    HStack(spacing: 10) {
                        CachedAsyncImage(
                            url: URL(string: BiliAPI.coverThumb(video.upAvatar, width: 80)),
                            targetSize: CGSize(width: 40, height: 40)
                        ) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(video.upName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text(upFans > 0 ? "\(upFans > 10000 ? String(format: "%.1f万", Double(upFans)/10000) : "\(upFans)") 粉丝" : "UP主")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Button {
                    toggleFollow()
                } label: {
                    HStack(spacing: 4) {
                        if isFollowBusy {
                            ProgressView().tint(isFollowing ? .secondary : .white).scaleEffect(0.8)
                        } else {
                            Image(systemName: isFollowing ? "checkmark" : "plus")
                        }
                        Text(isFollowing ? "已关注" : "关注")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(isFollowing ? Color.secondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color(.systemGray5) : Color.biliBlue)
                    .clipShape(Capsule())
                }
                .disabled(isFollowBusy)
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
                                  active: isLiked) { doLike() }
                interactionButton(icon: "hand.thumbsdown", count: nil, label: "不喜欢", active: false) {}
                interactionButton(icon: "dollarsign.circle", count: video.coins, label: "投币", active: false) { doCoin() }
                interactionButton(icon: isFavorited ? "star.fill" : "star",
                                  count: video.favorites + (isFavorited ? 1 : 0),
                                  label: isFavorited ? "已藏" : "收藏",
                                  active: isFavorited) { doFavorite() }
                interactionButton(icon: "arrowshape.turn.up.right.fill", count: video.shares, label: "分享", active: false) { doShare() }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider().padding(.horizontal)

            // Tags area reserved (not returned by basic view API)
            if !video.desc.isEmpty {
                Spacer().frame(height: 8)
            }
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
                    if isSendingComment {
                        ProgressView().tint(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.biliBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text("发送")
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.biliBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty || isSendingComment)
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
        // Activate playback audio session so audio plays even with the silent switch on.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("[BiliBili] AVAudioSession setup failed: \(error)")
        }
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
                p.automaticallyWaitsToMinimizeStalling = true
                p.isMuted = false
                p.volume = 1.0
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
        BiliAPI.shared.fetchComments(bvid: video.id) { c, aid in
            DispatchQueue.main.async {
                comments = c
                self.aid = aid
            }
        }
    }

    private func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        guard store.currentUser != nil else {
            toast = "请先登录"
            return
        }
        guard aid > 0 else {
            toast = "评论加载中，请稍候"
            return
        }
        isSendingComment = true
        BiliAPI.shared.postComment(aid: aid, message: text) { success, msg in
            DispatchQueue.main.async {
                isSendingComment = false
                if success {
                    let new = Comment(user: store.currentUser?.name ?? "我",
                                      avatar: store.currentUser?.avatar ?? "",
                                      content: text, likes: 0, time: "刚刚")
                    comments.insert(new, at: 0)
                    commentText = ""
                    toast = "评论成功"
                } else {
                    toast = msg ?? "评论失败"
                }
            }
        }
    }

    // MARK: - Real actions (follow / like / coin / favorite)

    private func toggleFollow() {
        guard store.currentUser != nil else {
            toast = "请先登录后再关注"
            return
        }
        guard video.upMid > 0 else { return }
        isFollowBusy = true
        let action = isFollowing ? 2 : 1
        BiliAPI.shared.modifyRelation(mid: video.upMid, action: action) { success, msg in
            DispatchQueue.main.async {
                isFollowBusy = false
                if success {
                    isFollowing.toggle()
                    toast = isFollowing ? "关注成功" : "已取消关注"
                } else {
                    toast = msg ?? "操作失败"
                }
            }
        }
    }

    private func doLike() {
        guard store.currentUser != nil else {
            toast = "请先登录"
            return
        }
        BiliAPI.shared.likeVideo(bvid: video.id, like: !isLiked) { success, msg in
            DispatchQueue.main.async {
                if success {
                    isLiked.toggle()
                    toast = isLiked ? "点赞成功" : "已取消点赞"
                } else {
                    toast = msg ?? "点赞失败"
                }
            }
        }
    }

    private func doCoin() {
        guard store.currentUser != nil else {
            toast = "请先登录"
            return
        }
        BiliAPI.shared.coinVideo(bvid: video.id) { success, msg in
            DispatchQueue.main.async {
                toast = success ? "投币成功" : (msg ?? "投币失败")
            }
        }
    }

    private func doFavorite() {
        guard store.currentUser != nil else {
            toast = "请先登录"
            return
        }
        BiliAPI.shared.favoriteVideo(bvid: video.id) { success, msg in
            DispatchQueue.main.async {
                if success {
                    isFavorited = true
                    toast = "收藏成功"
                } else {
                    toast = msg ?? "收藏失败"
                }
            }
        }
    }

    private func doShare() {
        let url = URL(string: "https://www.bilibili.com/video/\(video.id)")!
        let activityVC = UIActivityViewController(activityItems: [video.title, url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
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
            CachedAsyncImage(
                url: URL(string: BiliAPI.coverThumb(comment.avatar, width: 64)),
                targetSize: CGSize(width: 32, height: 32)
            ) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.3))
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
