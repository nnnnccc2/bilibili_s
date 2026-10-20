//
//  ContentView.swift
//  BiliBili
//
//  Main container with a floating pill bottom navigation (4 tabs).
//

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab = 0
    @State private var showingSearch = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(showingSearch: $showingSearch)
                    .tag(0)
                    .toolbar(.hidden, for: .tabBar)

                FollowingView(showingSearch: $showingSearch)
                    .tag(1)
                    .toolbar(.hidden, for: .tabBar)

                ProfileView(showingSearch: $showingSearch)
                    .tag(2)
                    .toolbar(.hidden, for: .tabBar)
            }
            .tint(.biliBlue)
            .background(Color.biliBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }

            // 搜索：overlay + 自定义 transition（从右侧滑入，不用 fullScreenCover 的"从下往上"）。
            if showingSearch {
                SearchView(onDismiss: { showingSearch = false })
                    .environmentObject(store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.biliBackground.ignoresSafeArea())
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                    .zIndex(10)
            }
        }
        .animation(MiniBiliAnimation.contentAppear, value: showingSearch)
    }

    // MARK: - Floating pill navigation (首页 / 关注 / 我的 + 搜索)
    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabButton(index: 0, icon: "house", selectedIcon: "house.fill", title: "首页")
            tabButton(index: 1, icon: "safari", selectedIcon: "safari.fill", title: "关注")
            tabButton(index: 2, icon: "person", selectedIcon: "person.fill", title: "我的")

            Button {
                showingSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(selectedTab == -1 ? Color.biliBlue : Color.biliTabText)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.05)))
                    .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .frame(height: 56)
        .padding(.horizontal, 12)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.biliBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabButton(index: Int, icon: String, selectedIcon: String, title: String) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 2) {
                Image(systemName: selectedTab == index ? selectedIcon : icon)
                    .font(.system(size: 18))
                    .scaleEffect(selectedTab == index ? 1.08 : 1)
                    .foregroundStyle(selectedTab == index ? Color.biliBlue : Color.biliMuted)
                Text(title)
                    .font(.system(size: 10, weight: selectedTab == index ? .bold : .medium))
                    .foregroundStyle(selectedTab == index ? Color.biliBlue : Color.biliSubtext)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .animation(MiniBiliAnimation.tabSelect, value: selectedTab)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Press feedback

/// Subtle press feedback (slight shrink + dim) shared by cards and rows, so
/// taps feel responsive instead of dead.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(MiniBiliAnimation.press, value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}

// MARK: - Shared animation curves

/// 全局动画曲线：全部换成弹簧 (spring)，带一点弹性/过冲感，
/// 比之前的 .snappy / .smooth 更有"活着"的质感。
/// 全屏页面进出交给系统模态动画（NavigationStack push / fullScreenCover）。
enum MiniBiliAnimation {

    /// 标签选中反馈：短响应 + 强阻尼 → 干脆的弹性吸附。
    static let tabSelect: Animation = .spring(response: 0.28, dampingFraction: 0.55, blendDuration: 0)
    /// 按压反馈：短响应 + 中等阻尼 → 明显的"弹一下"按压感。
    static let press: Animation = .spring(response: 0.22, dampingFraction: 0.48, blendDuration: 0)

    /// 内容出现（搜索结果、视频列表刷新）：稍长响应 + 强阻尼 → 柔和地弹入。
    static let contentAppear: Animation = .spring(response: 0.5, dampingFraction: 0.78, blendDuration: 0)
    /// 界面控件显示/隐藏（播放器控制条、就绪态等）：标准弹簧 → 干净、有反馈。
    static let uiReveal: Animation = .spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0)

    /// 卡片进入屏幕（staggered 配合 opacity+scale transition）：响应稍长。
    static let cardEnter: Animation = .spring(response: 0.55, dampingFraction: 0.72, blendDuration: 0.1)
    /// 列表头出现（hero/分区标题等）：长响应 + 强阻尼 → 温柔降临。
    static let headerDrop: Animation = .spring(response: 0.65, dampingFraction: 0.82, blendDuration: 0)
}

// MARK: - Card / list transitions

extension AnyTransition {
    /// 卡片/列表项进场：scale(0.88→1) + opacity(0→1) 组合，比纯 opacity 有更"弹"的感觉。
    static var cardEnter: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.88, anchor: .top).combined(with: .opacity),
            removal: .opacity
        )
    }
}

// MARK: - Immersive overlay helper

/// 全屏页面统一改用系统模态呈现（fullScreenCover），系统原生滑入/滑出。
/// 旧的缩放/暗底浮层（ImmersiveOverlay）已移除，动画全部交给系统。


// MARK: - Video player overlay (淡入淡出，不要从下往上)

/// 全屏播放器 overlay：用 `.transition(.opacity)` 代替 fullScreenCover 的"从下往上"系统动画。
/// 外层 View 会被包在 overlay 里，播放器淡入覆盖整个屏幕。
extension View {
    /// 给当前 View 加一个播放器 overlay，用淡入淡出过渡。
    func playerOverlay(for video: Binding<Video?>, store: AppStore) -> some View {
        overlay(alignment: .top) {
            if let v = video.wrappedValue {
                VideoPlayerView(video: v, onDismiss: { video.wrappedValue = nil })
                    .environmentObject(store)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .animation(MiniBiliAnimation.uiReveal, value: video.wrappedValue?.id)
                    .zIndex(99)
            }
        }
    }
}
