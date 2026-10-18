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
        .animation(store.animation.enterAnimation, value: store.immersiveDepth)
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

// MARK: - Immersive overlay helper

/// Marks a full-screen overlay (video player / UP空间 / 设置 / 搜索).
/// While it is presented the bottom tab bar is hidden.
///
/// The motion itself is not hard-coded here: it is read from `store.animation`,
/// which 动画实验室（设置页）exposes so the feel can be tried on the real screens
/// before being decided. It defaults to the quiet "韧带" dissolve — no direction,
/// no bounce, just the page being there.
///
/// The entrance is driven by internal state, so it works even when the call-site
/// doesn't wrap its state change in `withAnimation`; the exit uses a matching
/// removal transition animated by `dismissImmersive`.
struct ImmersiveOverlay: ViewModifier {
    @EnvironmentObject var store: AppStore
    @State private var appeared = false

    private var config: OverlayAnimationSettings { store.animation }

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : CGFloat(config.rise))
            .scaleEffect(appeared ? 1 : CGFloat(config.scaleFrom))
            .transition(.asymmetric(
                insertion: .identity,
                removal: exitTransition))
            .onAppear {
                store.pushImmersive()
                withAnimation(config.enterAnimation) { appeared = true }
            }
            .onDisappear { store.popImmersive() }
    }

    /// Mirrors the entrance on the way out, with the same distance and pop.
    private var exitTransition: AnyTransition {
        var transition: AnyTransition = .opacity
        if config.rise > 0 {
            transition = transition.combined(with: .offset(y: CGFloat(config.rise) * 0.6))
        }
        if config.scaleFrom != 1 {
            transition = transition.combined(with: .scale(scale: CGFloat(config.scaleFrom)))
        }
        return transition
    }
}

extension View {
    func immersive() -> some View {
        modifier(ImmersiveOverlay())
    }
}

/// Animates an overlay dismissal with the same configured motion as the entrance.
func dismissImmersive(_ action: @escaping () -> Void) {
    withAnimation(OverlayAnimationSettings.persisted.exitAnimation) { action() }
}
