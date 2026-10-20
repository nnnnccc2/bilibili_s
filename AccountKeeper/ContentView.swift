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
            // Hide the tab bar while an immersive overlay is on screen.
            if store.immersiveDepth == 0 {
                bottomBar
                    .transition(.opacity)
            }
        }
        .animation(MiniBiliAnimation.tabBar, value: store.immersiveDepth)
        .overlay {
            if showingSearch {
                SearchView(onDismiss: { dismissImmersive { showingSearch = false } })
                    .environmentObject(store)
                    .immersive()
                    .zIndex(50)
            }
        }
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

// MARK: - MiniBili animation system

/// 全局动画体系：统一使用苹果原生曲线（iOS 17+），顺滑、自然、克制。
/// 所有页面过渡与交互反馈都走这套手感，保证全应用动画语言一致。
enum MiniBiliAnimation {

    // MARK: 沉浸式浮层过渡（页面进出）

    /// 进场起始缩放：从极近位置归位，如清水覆过。
    static let enterStartScale: CGFloat = 0.97
    /// 进场起始透明度：0.9 → 1，略带通透如清水，不做浓重淡入。
    static let enterStartOpacity: Double = 0.9
    /// 非视频页空隙填充的暗度：极淡，清水感。
    static let enterDim: Double = 0.10

    /// 进场：苹果原生 .smooth 顺滑弹簧，无回弹、落定自然。
    static let enter: Animation = .smooth
    /// 退场：苹果原生 .smooth，顺滑淡出。
    static let exit: Animation = .smooth

    // MARK: 标签栏与交互

    /// 标签栏隐藏/显示：苹果原生 .smooth。
    static let tabBar: Animation = .smooth
    /// 标签选中反馈：苹果原生 .snappy，干脆利落。
    static let tabSelect: Animation = .snappy
    /// 按压反馈：苹果原生 .snappy，响应即时。
    static let press: Animation = .snappy

    // MARK: 内容与控件

    /// 内容出现（搜索结果、列表）：苹果原生 .smooth。
    static let contentAppear: Animation = .smooth
    /// 界面控件显示/隐藏（播放器控制条、就绪态等）：苹果原生 .smooth。
    static let uiReveal: Animation = .smooth
}

// MARK: - Immersive overlay helper

/// Marks a full-screen overlay (video player / UP空间 / 设置 / 搜索).
/// While it is presented the bottom tab bar is hidden.
///
/// 进场：内容从 0.97 放大铺满，苹果原生 .smooth 顺滑落定。
///   - 缩放锚点 .top：顶部边缘始终贴住屏幕顶端，视频不会先沉后升，刘海区无位移。
///   - 不模糊、不加阴影：内容略带通透（0.9→1）如清水；阴影会让全屏缩放的每一帧都离屏重绘，拖慢过渡。
///   - 视频页（backdrop != nil）：黑色底即时铺满（不参与动画），刘海区全程黑色、绝不跳色。
///   - 其他页：极淡暗底随进场淡入，轻量连接前后两页。
/// 退场：统一顺滑淡出。
///
/// The entrance is driven by internal state, so it works even when the call-site
/// doesn't wrap its state change in `withAnimation`.
struct ImmersiveOverlay: ViewModifier {
    @EnvironmentObject var store: AppStore
    @State private var appeared = false

    /// 覆盖层后面垫的底色。视频页传 .black，保证刘海区域始终是黑的、不跳色。
    var backdrop: Color? = nil

    /// 空隙里要填充的颜色与目标不透明度。
    private var fillColor: Color { backdrop ?? .black }
    private var fillTarget: Double {
        backdrop != nil ? 1 : MiniBiliAnimation.enterDim
    }

    /// 视频页底色即时铺满（不做透明度动画），杜绝刘海跳色；
    /// 其他页底色随进场淡入，轻量连接。
    private var fillOpacity: Double {
        backdrop != nil ? fillTarget : (appeared ? fillTarget : 0)
    }

    /// 视频页（backdrop != nil）内容不做任何缩放/淡入：直接满尺寸、全不透明出现。
    /// 视频内容承载 AVPlayerLayer，对它逐帧缩放会掉帧并产生播放区位移；
    /// 仅靠即时铺满的黑色底完成过渡，最干脆也最流畅。
    /// 其他页保留极近的缩放 + 轻微通透，做出轻量的进场连接感。
    private var contentScale: CGFloat {
        backdrop != nil ? 1 : (appeared ? 1 : MiniBiliAnimation.enterStartScale)
    }
    private var contentOpacity: Double {
        backdrop != nil ? 1 : (appeared ? 1 : MiniBiliAnimation.enterStartOpacity)
    }

    func body(content: Content) -> some View {
        ZStack {
            fillColor
                .ignoresSafeArea()
                .opacity(fillOpacity)
            content
                // 锚点在顶部：上沿全程贴顶，缩放只向下展开，杜绝位移。
                .scaleEffect(contentScale, anchor: .top)
                // 不加阴影：全屏内容缩放的阴影需逐帧离屏重绘，是过渡顿挫的主因。
                .opacity(contentOpacity)
        }
        .transition(.asymmetric(
            insertion: .identity,
            removal: .opacity))
        .onAppear {
            store.pushImmersive()
            withAnimation(MiniBiliAnimation.enter) { appeared = true }
        }
        .onDisappear { store.popImmersive() }
    }
}

extension View {
    func immersive(backdrop: Color? = nil) -> some View {
        modifier(ImmersiveOverlay(backdrop: backdrop))
    }
}

/// Animates an overlay dismissal with the shared MiniBili exit feel.
func dismissImmersive(_ action: @escaping () -> Void) {
    withAnimation(MiniBiliAnimation.exit) { action() }
}
