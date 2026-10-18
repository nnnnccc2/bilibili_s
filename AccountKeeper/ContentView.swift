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

// MARK: - Overlay connection transition

/// 全屏浮层的“连接”方式——把旧页面和新页面接起来。
/// 可在 关于 → 页面过渡 里开关与切换；退场统一是干净的快速淡出。
enum OverlayConnector: String, CaseIterable, Identifiable, Codable {
    case liquid     // 液体溶解
    case lift       // 轻微浮起
    case push       // 柔边推移
    case liftFade   // 浮起 + 溶解

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liquid: return "液体溶解"
        case .lift: return "轻微浮起"
        case .push: return "柔边推移"
        case .liftFade: return "浮起 + 溶解"
        }
    }

    var detail: String {
        switch self {
        case .liquid: return "淡入时由虚到实，像水面平复；不动几何，刘海和边缘不会露色。"
        case .lift: return "新页面从 99% 轻推到 100%，像从旧页面浮出来，幅度很小。"
        case .push: return "新页面从下方极短地推进来，随即归位，做出「沟槽」层次。"
        case .liftFade: return "轻微浮起的同时由虚到实，连接感最强。"
        }
    }
}

/// 浮层进场的手感配置。持久化到 UserDefaults，随 App 启动恢复。
struct OverlayTransition: Codable, Hashable {
    var enabled: Bool = false
    var connector: OverlayConnector = .liquid

    // —— 起始姿态（只作用在进场；退场始终是快速淡出）——
    var startScale: CGFloat {
        guard enabled else { return 1 }
        switch connector {
        case .lift, .liftFade: return 0.99
        case .liquid, .push: return 1
        }
    }

    var startOffset: CGFloat {
        guard enabled, connector == .push else { return 0 }
        return 8
    }

    var startBlur: CGFloat {
        guard enabled else { return 0 }
        switch connector {
        case .liquid: return 10
        case .liftFade: return 6
        case .lift, .push: return 0
        }
    }

    var enterAnimation: Animation {
        guard enabled else { return .easeOut(duration: 0.30) }
        switch connector {
        case .lift, .liftFade: return .spring(response: 0.28, dampingFraction: 0.9)
        case .liquid, .push: return .easeOut(duration: 0.18)
        }
    }

    // —— 持久化 ——
    private static let storageKey = "BiliBili.overlayTransition"

    static var persisted: OverlayTransition {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(OverlayTransition.self, from: data)
        else { return OverlayTransition() }
        return value
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

// MARK: - Immersive overlay helper

/// Marks a full-screen overlay (video player / UP空间 / 设置 / 搜索).
/// While it is presented the bottom tab bar is hidden.
///
/// 进场：内容立刻显现（很快），若在 关于 里打开了「页面过渡」，再叠一层连接动画
/// （溶解 / 浮起 / 推移），把前后两页接起来。
/// 退场：统一干净的快速淡出——不改几何，所以刘海与屏幕边缘不会露色。
///
/// The entrance is driven by internal state, so it works even when the call-site
/// doesn't wrap its state change in `withAnimation`.
struct ImmersiveOverlay: ViewModifier {
    @EnvironmentObject var store: AppStore
    @State private var appeared = false

    private var transition: OverlayTransition { store.overlayTransition }

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : transition.startScale)
            .offset(y: appeared ? 0 : transition.startOffset)
            .blur(radius: appeared ? 0 : transition.startBlur)
            .opacity(appeared ? 1 : 0)
            .transition(.asymmetric(
                insertion: .identity,
                removal: .opacity))
            .onAppear {
                store.pushImmersive()
                withAnimation(transition.enterAnimation) { appeared = true }
            }
            .onDisappear { store.popImmersive() }
    }
}

extension View {
    func immersive() -> some View {
        modifier(ImmersiveOverlay())
    }
}

/// Animates an overlay dismissal with the shared exit feel.
func dismissImmersive(_ action: @escaping () -> Void) {
    withAnimation(.easeOut(duration: 0.24)) { action() }
}
