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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Player
                    playerSection
                        .frame(height: 220)

                    // Title
                    Text(video.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    // Stats row
                    HStack(spacing: 16) {
                        stat(icon: "play.fill", value: video.viewsText, label: "播放")
                        stat(icon: "list.bullet", value: "\(video.danmaku)", label: "弹幕")
                        stat(icon: "calendar", value: video.publishTime, label: "")
                        Spacer()
                    }
                    .padding(.horizontal)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Divider()
                        .padding(.horizontal)

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
                            Text("UP主")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            // follow action (mock)
                        } label: {
                            Text("+ 关注")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.pink)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)

                    // Interaction bar
                    HStack(spacing: 0) {
                        interactionButton(icon: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                                          count: video.likes + (isLiked ? 1 : 0),
                                          active: isLiked) { isLiked.toggle() }
                        interactionButton(icon: "hand.thumbsdown", count: 0, active: false) {}
                        interactionButton(icon: "star.fill", count: video.coins, active: false) {}
                        interactionButton(icon: "heart.fill",
                                          count: video.favorites + (isFavorited ? 1 : 0),
                                          active: isFavorited) { isFavorited.toggle() }
                        interactionButton(icon: "arrowshape.turn.up.right.fill", count: video.shares, active: false) {}
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    Divider()

                    // Description
                    if !video.desc.isEmpty {
                        Text("简介：\(video.desc)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    Divider()

                    // Comments section
                    HStack {
                        Text("评论 \(comments.count)")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)

                    ForEach(comments) { c in
                        CommentRow(comment: c)
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                    }

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
                                .background(Color.pink)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFullScreen.toggle() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
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

    // MARK: - Player section

    @ViewBuilder
    private var playerSection: some View {
        if let player = player {
            VideoPlayer(player: player)
                .background(Color.black)
                .onAppear {
                    player.play()
                    writeHistoryOnce()
                }
        } else {
            ZStack {
                Color.black
                VStack {
                    Image(systemName: "play.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("视频加载失败")
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 8)
                    Button("重试") { setupPlayer() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .padding(.top, 8)
                }
            }
        }
    }

    private func setupPlayer() {
        if let url = BiliAPI.shared.streamURL(for: video) {
            player = AVPlayer(url: url)
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

    private func stat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(value)
            if !label.isEmpty { Text(label) }
        }
    }

    private func interactionButton(icon: String, count: Int, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(active ? Color.pink : .primary)
                Text(count > 10000 ? String(format: "%.1f万", Double(count)/10000) : "\(count)")
                    .font(.caption2)
                    .foregroundStyle(active ? Color.pink : .secondary)
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
