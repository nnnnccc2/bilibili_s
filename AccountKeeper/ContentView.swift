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
        .animation(.easeOut(duration: 0.15), value: store.immersiveDepth)
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
        .background(Color.white.opacity(0.8))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
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
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: selectedTab)
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
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}

// MARK: - Immersive overlay transition (resilient only)

/// 全屏浮层进场的固定手感：干净、像清水。
/// 这是一个主打信息过滤、去除杂质的应用，动画应如清水般通透轻盈——
/// 内容从极近的位置（0.97）快速归位，略带一丝透明（0.9→1）如清水覆过，
/// 不模糊、不加厚重阴影，只靠一层极淡暗底与一丝柔影自然托出厚度。
/// 缩放锚点在顶部，视频上沿全程贴住屏幕顶端，无位移。
/// 时长为原始韧性动画的 0.7 倍（原始 response 0.42 → 0.294）。
private enum ResilientTransition {
    static let startScale: CGFloat = 0.97
    static let startOffset: CGFloat = 0
    static let startDim: Double = 0.10
    // 内容起始透明度：0.9 → 1，如清水般略带通透，不做浓重淡入。
    static let startOpacity: Double = 0.9
    // 极淡柔影：自然托出厚度，不抢戏、不厚重。
    static let shadowRadius: CGFloat = 12
    static let shadowOpacity: Double = 0.15
    // 0.7 × 原始 0.42 = 0.294；阻尼 0.86 → 克制回弹，干脆落定。
    static let enterAnimation: Animation = .spring(response: 0.294, dampingFraction: 0.86)
}

// MARK: - Immersive overlay helper

/// Marks a full-screen overlay (video player / UP空间 / 设置 / 搜索).
/// While it is presented the bottom tab bar is hidden.
///
/// 进场：内容从 0.97 放大铺满，干脆落定。
///   - 缩放锚点 .top：顶部边缘始终贴住屏幕顶端，视频不会先沉后升，刘海区无位移。
///   - 不模糊：内容略带通透（0.9→1）如清水，配极淡柔影自然托出厚度。
///   - 视频页（backdrop != nil）：黑色底即时铺满（不参与动画），刘海区全程黑色、绝不跳色。
///   - 其他页：极淡暗底随进场淡入，轻量连接前后两页。
/// 退场：统一干净的快速淡出。
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
        backdrop != nil ? 1 : ResilientTransition.startDim
    }

    /// 视频页底色即时铺满（不做透明度动画），杜绝刘海跳色；
    /// 其他页底色随进场淡入，轻量连接。
    private var fillOpacity: Double {
        backdrop != nil ? fillTarget : (appeared ? fillTarget : 0)
    }

    func body(content: Content) -> some View {
        ZStack {
            fillColor
                .ignoresSafeArea()
                .opacity(fillOpacity)
            content
                // 锚点在顶部：上沿全程贴顶，缩放只向下展开，杜绝位移。
                .scaleEffect(appeared ? 1 : ResilientTransition.startScale, anchor: .top)
                .offset(y: appeared ? 0 : ResilientTransition.startOffset)
                // 极淡柔影：自然厚度，不厚重。
                .shadow(color: .black.opacity(ResilientTransition.shadowOpacity),
                        radius: ResilientTransition.shadowRadius)
                // 内容略带通透如清水（0.9→1），不模糊、不浓重淡入。
                .opacity(appeared ? 1 : ResilientTransition.startOpacity)
        }
        .transition(.asymmetric(
            insertion: .identity,
            removal: .opacity))
        .onAppear {
            store.pushImmersive()
            withAnimation(ResilientTransition.enterAnimation) { appeared = true }
        }
        .onDisappear { store.popImmersive() }
    }
}

extension View {
    func immersive(backdrop: Color? = nil) -> some View {
        modifier(ImmersiveOverlay(backdrop: backdrop))
    }
}

/// Animates an overlay dismissal with the shared exit feel.
func dismissImmersive(_ action: @escaping () -> Void) {
    withAnimation(.easeOut(duration: 0.25)) { action() }
}
