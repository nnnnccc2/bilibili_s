//
//  VideoPlayerView.swift
//  BiliBili
//
//  Video player & detail page. Pure playback, NO danmaku.
//  Custom controls: play/pause bottom-left, fullscreen bottom-right, NO AirPlay.
//

import SwiftUI
import AVFoundation
import UIKit

struct VideoPlayerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let video: Video
    var onDismiss: (() -> Void)? = nil

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

    // Playback controls UI state
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0
    @State private var gestureStartTime: Double = 0
    @State private var upAvatar: String = ""
    @State private var upNameOverride: String = ""
    @State private var rateObservation: NSKeyValueObservation?
    @State private var statusObservation: NSKeyValueObservation?
    @State private var isReady = false
    /// Guards the one-shot DASH → progressive fallback so we never build two players.
    @State private var didFallBack = false

    // Swipe gesture state
    @State private var gestureStartX: CGFloat = 0
    @State private var gestureStartY: CGFloat = 0
    @State private var gestureStartVolume: Float = 1.0
    @State private var gestureStartBrightness: CGFloat = UIScreen.main.brightness
    @State private var gestureDirection: GestureDirection = .none
    @State private var showGestureIndicator: Bool = false
    @State private var gestureSymbol: String = "goforward.10"
    @State private var gestureLevel: CGFloat = 0.5

    private enum GestureDirection { case none, horizontal, verticalLeft, verticalRight }

    /// Top safe-area inset (notch / Dynamic Island) so controls & video sit below it.
    private var topSafeArea: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        guard let ws = scenes.first as? UIWindowScene else { return 0 }
        let window = ws.windows.first(where: { $0.isKeyWindow }) ?? ws.windows.first
        return window?.safeAreaInsets.top ?? 0
    }

    /// Bottom safe-area inset (home indicator) so controls sit above it.
    private var bottomSafeArea: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        guard let ws = scenes.first as? UIWindowScene else { return 0 }
        let window = ws.windows.first(where: { $0.isKeyWindow }) ?? ws.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Dark background so letterbox areas are black, not white
            Color.black.ignoresSafeArea()

            if showFullScreen {
                // True full-screen: player edge-to-edge with the shared controls
                ZStack {
                    PlayerLayerView(player: player)
                        .ignoresSafeArea()
                        .opacity(isReady ? 1 : 0)
                        .animation(MiniBiliAnimation.uiReveal, value: isReady)
                    gestureIndicatorView
                    interactionLayer
                        .ignoresSafeArea()
                    if showControls {
                        playerControlsChrome(fullscreen: true)
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Explicit notch-height spacer: the ScrollView ignores the
                        // top safe area, so this places the video exactly at the
                        // bottom edge of the notch (never under it, no gap).
                        Color.black
                            .frame(height: topSafeArea)
                            .frame(maxWidth: .infinity)

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
                .ignoresSafeArea(edges: .top)
            }
        }
        .overlay(alignment: .top) {
            // Pinned black strip over the notch/status-bar area (inline mode only)
            // so the top stays black even when the content scrolls.
            if !showFullScreen {
                Color.black
                    .frame(height: topSafeArea)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            setupPlayer()
            loadComments()
            if video.upMid > 0 {
                BiliAPI.shared.fetchUPSpaceInfo(mid: video.upMid) { info in
                    DispatchQueue.main.async {
                        upFans = info?.fans ?? 0
                        // Search results & UP-space lists don't carry the UP avatar;
                        // fill it in from the profile so the player always shows one.
                        if let face = info?.avatar, !face.isEmpty {
                            upAvatar = face
                        }
                    }
                }
            } else if video.category == "影视" {
                // PGC seasons have no UP主; use the season's official owner so the
                // player still shows an avatar and name.
                BiliAPI.shared.fetchPgcSeasonOwner(seasonId: video.id) { info in
                    DispatchQueue.main.async {
                        guard let info = info else { return }
                        if !info.avatar.isEmpty { upAvatar = info.avatar }
                        if !info.name.isEmpty { upNameOverride = info.name }
                        if info.fans > 0 { upFans = info.fans }
                    }
                }
            }
            if store.currentUser != nil, video.upMid > 0 {
                BiliAPI.shared.checkRelation(mid: video.upMid) { following in
                    DispatchQueue.main.async { isFollowing = following }
                }
            }
        }
        .onDisappear {
            // Pause & release this player when leaving; PlayerManager ensures
            // switching to another video pauses the previous one.
            rateObservation?.invalidate()
            rateObservation = nil
            statusObservation?.invalidate()
            statusObservation = nil
            isReady = false
            if let p = player {
                p.pause()
                PlayerManager.shared.deactivate(p)
            }
        }
        .overlay {
            if showingUPSpace, video.upMid > 0 {
                UPSpaceView(mid: video.upMid, initialName: video.upName, onDismiss: { dismissImmersive({ showingUPSpace = false }) })
                    .environmentObject(store)
                    .ignoresSafeArea()
                    .immersive()
                    .zIndex(30)
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
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { self.toast = nil }
                    }
            }
        }
        .statusBarHidden(showFullScreen)
    }

    // MARK: - Shared player controls (used by BOTH inline & full-screen)

    /// Full-area layer that toggles the controls on tap and drives the
    /// brightness / volume / seek swipe gestures. Sits BELOW the control chrome
    /// so buttons and the progress bar always receive touches first.
    private var interactionLayer: some View {
        Color.black.opacity(0.001)
            .contentShape(Rectangle())
            .onTapGesture { toggleControls() }
            .gesture(playerGesture)
    }

    /// Short side of the playback area (width in inline mode, min(w,h) full screen).
    private var playbackSide: CGFloat {
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        return showFullScreen ? min(w, h) : (w * 9.0 / 16.0)
    }

    /// Scale the gesture HUD with the size of the playback area, so the card
    /// stays proportionate in the small inline player and on the full screen.
    private var hudScale: CGFloat {
        min(max(playbackSide / 330.0, 0.70), 0.90)
    }

    /// Gesture HUD: an icon plus a level bar styled exactly like the seek bar
    /// (same track/fill/knob) in a compact dark pill — no numbers.
    private var gestureIndicatorView: some View {
        let s = hudScale
        let barW = min(max(playbackSide * 0.42, 84), 140)
        let knob: CGFloat = 7
        let frac = min(max(gestureLevel, 0), 1)
        return Group {
            if showGestureIndicator {
                VStack(spacing: 6) {
                    Image(systemName: gestureSymbol)
                        .font(.system(size: 15 * s, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.28)).frame(width: barW, height: 3)
                        Capsule().fill(Color.white).frame(width: max(3, barW * frac), height: 3)
                        Circle()
                            .fill(Color.white)
                            .frame(width: knob, height: knob)
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                            .offset(x: max(0, min(barW - knob, barW * frac - knob / 2)))
                    }
                    .frame(width: barW, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 10 * s, style: .continuous))
                .transition(.opacity)
            }
        }
    }

    /// Back button + bottom control bar. Same set of controls in both modes.
    @ViewBuilder
    private func playerControlsChrome(fullscreen: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    if let onDismiss = onDismiss { onDismiss() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, fullscreen ? topSafeArea + 6 : 8)

            Spacer()

            controlBar(fullscreen: fullscreen)
                .padding(.horizontal, 14)
                .padding(.bottom, fullscreen ? bottomSafeArea + 8 : 10)
        }
        .transition(.opacity)
    }

    /// One clean row: play/pause · current time · seek bar · total time · fullscreen.
    private func controlBar(fullscreen: Bool) -> some View {
        HStack(spacing: 10) {
            Button { togglePlay() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(formatTime(isScrubbing ? scrubTime : currentTime))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))

            playProgressBar

            Text(formatTime(duration))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))

            Button {
                showFullScreen.toggle()
                scheduleHideControls()
            } label: {
                Image(systemName: fullscreen
                              ? "arrow.down.right.and.arrow.up.left"
                              : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        )
    }

    /// Slim seek bar, on the same line as play/pause. While dragging it only
    /// updates the UI; the seek is committed once on release so scrubbing
    /// stays smooth and the video never stutters.
    private var playProgressBar: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let shown = isScrubbing ? scrubTime : currentTime
            let frac = duration > 0 ? min(max(shown / duration, 0), 1) : 0
            let knob: CGFloat = isScrubbing ? 12 : 9
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(height: 3)
                Capsule()
                    .fill(Color.white)
                    .frame(width: CGFloat(frac) * w, height: 3)
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(x: CGFloat(frac) * w - knob / 2)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        if !isScrubbing {
                            isScrubbing = true
                            showControls = true
                            controlsTimer?.invalidate()
                        }
                        scrubTime = min(max(value.location.x / w, 0), 1) * duration
                    }
                    .onEnded { value in
                        guard duration > 0, let p = player else { isScrubbing = false; return }
                        let t = min(max(value.location.x / w, 0), 1) * duration
                        scrubTime = t
                        // Keep isScrubbing while the seek is in flight so the
                        // periodic observer can't bounce the thumb back to the
                        // old position before the seek lands.
                        p.seek(to: CMTime(seconds: t, preferredTimescale: 600)) { _ in
                            DispatchQueue.main.async {
                                currentTime = t
                                isScrubbing = false
                            }
                        }
                        scheduleHideControls()
                    }
            )
        }
        .frame(height: 22)
    }

    // MARK: - Inline player section (shared controls)

    @ViewBuilder
    private var playerSection: some View {
        ZStack {
            Color.black
            if let player = player {
                PlayerLayerView(player: player)
                    .opacity(isReady ? 1 : 0)
                    .animation(MiniBiliAnimation.uiReveal, value: isReady)
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
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            gestureIndicatorView

            // Tap + swipe layer (below controls so buttons/seek bar win touches)
            interactionLayer

            if showControls {
                playerControlsChrome(fullscreen: false)
            }
        }
    }

    private var playerGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if gestureDirection == .none {
                    // Determine direction on first significant movement
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > abs(dy) {
                        // Horizontal = seek: drive the real seek bar, no card.
                        gestureDirection = .horizontal
                        gestureStartX = value.startLocation.x
                        gestureStartTime = currentTime
                        scrubTime = currentTime
                        isScrubbing = true
                        showControls = true
                        controlsTimer?.invalidate()
                    } else {
                        let isLeft = value.startLocation.x < UIScreen.main.bounds.width / 2
                        gestureDirection = isLeft ? .verticalLeft : .verticalRight
                        gestureStartY = value.startLocation.y
                        gestureStartVolume = PlayerManager.shared.volume
                        gestureStartBrightness = UIScreen.main.brightness
                        gestureSymbol = isLeft ? "sun.max.fill" : "speaker.wave.3.fill"
                        if isLeft {
                            gestureLevel = UIScreen.main.brightness
                        } else {
                            gestureLevel = CGFloat(PlayerManager.shared.volume)
                        }
                        showGestureIndicator = true
                    }
                }

                switch gestureDirection {
                case .horizontal:
                    // Seek: 1px ≈ 0.5s. Only the thumb moves; the seek is
                    // committed once on release so playback stays smooth.
                    let target = gestureStartTime + Double(value.translation.width) * 0.5
                    scrubTime = min(max(target, 0), max(duration, 0))
                case .verticalLeft:
                    // Brightness: full screen height = full brightness range
                    let height = UIScreen.main.bounds.height
                    let delta = (gestureStartY - value.location.y) / height
                    let newBrightness = min(max(gestureStartBrightness + delta, 0), 1)
                    UIScreen.main.brightness = newBrightness
                    gestureLevel = newBrightness
                case .verticalRight:
                    // Volume: full screen height = full volume range
                    let height = UIScreen.main.bounds.height
                    let delta = Float((gestureStartY - value.location.y) / height)
                    let newVolume = min(max(gestureStartVolume + delta, 0), 1)
                    PlayerManager.shared.setVolume(newVolume)
                    gestureLevel = CGFloat(newVolume)
                case .none:
                    break
                }
            }
            .onEnded { _ in
                switch gestureDirection {
                case .horizontal:
                    if let p = player {
                        let t = scrubTime
                        p.seek(to: CMTime(seconds: t, preferredTimescale: 600)) { _ in
                            DispatchQueue.main.async {
                                currentTime = t
                                isScrubbing = false
                            }
                        }
                        scheduleHideControls()
                    } else {
                        isScrubbing = false
                    }
                default:
                    break
                }
                gestureDirection = .none
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showGestureIndicator = false
                }
            }
    }

    // MARK: - Controls helpers

    private func toggleControls() {
        withAnimation(MiniBiliAnimation.uiReveal) {
            showControls.toggle()
        }
        if showControls { scheduleHideControls() }
    }

    private func scheduleHideControls() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(MiniBiliAnimation.uiReveal) { showControls = false }
            }
        }
    }

    private func togglePlay() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else {
            return String(format: "%d:%02d", m, sec)
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

    // MARK: - Intro section

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(video.title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
                .padding(.horizontal)
                .padding(.top, 8)

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

            HStack(spacing: 10) {
                Button {
                    if video.upMid > 0 { showingUPSpace = true }
                } label: {
                    HStack(spacing: 10) {
                        CachedAsyncImage(
                            url: URL(string: BiliAPI.coverThumb(upAvatar.isEmpty ? video.upAvatar : upAvatar, width: 80)),
                            targetSize: CGSize(width: 40, height: 40)
                        ) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(upNameOverride.isEmpty ? video.upName : upNameOverride)
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

            if !video.desc.isEmpty {
                Spacer().frame(height: 8)
            }
        }
    }

    // MARK: - Comments section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
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

    // MARK: - Player setup

    private var streamHeaders: [String: String] {
        [
            "Referer": "https://www.bilibili.com/",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        ]
    }

    private func setupPlayer() {
        isBuffering = true
        isReady = false
        // Activate the audio session BEFORE building the player — AVPlayer needs
        // it active to start reliably, so keep this on the main thread (doing it
        // asynchronously raced with playback and made some videos never start).
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("[BiliBili] AVAudioSession setup failed: \(error)")
        }
        BiliAPI.shared.resolveStream(for: video) { stream in
            DispatchQueue.main.async {
                isBuffering = false
                guard let stream = stream else {
                    // No playable stream (会员专享 / 地区限制 / 接口风控) — surface a
                    // message instead of spinning on a black screen forever.
                    self.toast = "该视频暂时无法播放"
                    return
                }
                self.startPlayback(stream)
            }
        }
    }

    private func startPlayback(_ stream: BiliAPI.PlayableStream) {
        switch stream {
        case .progressive(let url):
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": streamHeaders])
            attachPlayer(AVPlayerItem(asset: asset), allowFallback: false)
        case .asset(let asset):
            // Pre-muxed during prefetch — no muxing latency on tap.
            attachPlayer(AVPlayerItem(asset: asset), allowFallback: true)
            scheduleFallbackIfNotReady()
        case .dash(let videoURL, let audioURL):
            // Not pre-muxed (prefetch skipped or mux failed earlier) — mux now.
            BiliAPI.shared.buildDashComposition(videoURL: videoURL, audioURL: audioURL,
                                                knownSeconds: Double(max(video.duration, 0))) { asset in
                guard let asset = asset, !self.didFallBack else {
                    self.fallbackToProgressive()
                    return
                }
                self.attachPlayer(AVPlayerItem(asset: asset), allowFallback: true)
                self.scheduleFallbackIfNotReady()
            }
        }
    }

    /// Safety net: if a DASH stream never becomes playable, fall back to the
    /// progressive mp4 instead of leaving a stuck black player on screen.
    private func scheduleFallbackIfNotReady() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if !self.isReady { self.fallbackToProgressive() }
        }
    }

    private func fallbackToProgressive() {
        guard !didFallBack else { return }
        didFallBack = true
        BiliAPI.shared.progressiveFallback(for: video) { url in
            DispatchQueue.main.async {
                guard let url = url else {
                    self.toast = "该视频暂时无法播放"
                    return
                }
                let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": self.streamHeaders])
                self.attachPlayer(AVPlayerItem(asset: asset), allowFallback: false)
            }
        }
    }

    /// Attach a ready player item and wire up all observation.
    /// `allowFallback` is true only for DASH streams — a progressive failure is
    /// retried with the same kind of URL, which would just loop, so we skip it.
    private func attachPlayer(_ item: AVPlayerItem, allowFallback: Bool) {
        item.preferredForwardBufferDuration = 1.0
        let p = AVPlayer(playerItem: item)
        // `automaticallyWaitsToMinimizeStalling` is left at its default (true):
        // disabling it made some streams fail to start / stall immediately.
        // Reliability first; startup is handled by the small forward buffer above.
        p.rate = 1.0
        self.player = p
        // Pause any previously-playing video, then play this one.
        PlayerManager.shared.activate(p)
        p.play()
        isPlaying = true
        showControls = true
        scheduleHideControls()
        writeHistoryOnce()

        // Observe playback progress (update duration + currentTime). Skip
        // currentTime while the user is scrubbing so the thumb follows the
        // finger instead of fighting the playback clock.
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if !self.isScrubbing {
                self.currentTime = time.seconds
            }
            if let d = p.currentItem?.duration.seconds, !d.isNaN {
                self.duration = d
            }
        }
        // Playback ended → pause UI
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
            self.isPlaying = false
        }
        // Keep the play/pause icon in sync when this player is paused by someone
        // else — e.g. PlayerManager pauses it when another video starts.
        self.rateObservation = p.observe(\.rate, options: [.new]) { player, _ in
            DispatchQueue.main.async {
                self.isPlaying = player.rate != 0
            }
        }
        // Fade the video in once the asset is ready to render (no hard flash).
        // If the item fails — e.g. an unplayable DASH composition — fall back.
        self.statusObservation = item.observe(\.status, options: [.new]) { observed, _ in
            switch observed.status {
            case .readyToPlay:
                DispatchQueue.main.async {
                    withAnimation(MiniBiliAnimation.uiReveal) { self.isReady = true }
                }
            case .failed:
                if allowFallback {
                    DispatchQueue.main.async { self.fallbackToProgressive() }
                }
            default:
                break
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

    // MARK: - Real actions

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
