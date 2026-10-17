//
//  ContentView.swift
//  BiliBili
//
//  Main container with a floating pill bottom navigation (4 tabs).
//

import SwiftUI

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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.immersiveDepth)
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
/// The overlay sits on an opaque backdrop matching the app page colour, which
/// snaps in instantly — the page behind is never visible, so there is no white
/// flash — while the content scales + fades in gently for a smooth, unhurried
/// entrance. Dismissal fades out the same way.
struct ImmersiveOverlay: ViewModifier {
    @EnvironmentObject var store: AppStore
    var duration: Double = 0.5
    /// `false` = full-screen video (slightly smaller zoom-in); `true` = UP space
    /// / login / settings.
    var fadeIn: Bool = true
    @State private var appeared = false

    func body(content: Content) -> some View {
        ZStack {
            // Opaque backdrop matching the page colour (#F5FBFF) so the cross-fade
            // below is invisible and never exposes whatever page sits behind.
            Color.biliBackground.ignoresSafeArea()
            content
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : (fadeIn ? 0.96 : 0.97))
        }
        // Insertion is a no-op (the backdrop must not fade in over the page —
        // that is what produced the white flash); removal fades out.
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
        .onAppear {
            store.pushImmersive()
            // Slow, near-critically-damped spring: smooth settle, no bounce, and
            // no abrupt "pop" on the way in.
            withAnimation(.spring(response: duration, dampingFraction: 0.95)) {
                appeared = true
            }
        }
        .onDisappear { store.popImmersive() }
    }
}

extension View {
    func immersive(duration: Double = 0.5, fadeIn: Bool = true) -> some View {
        modifier(ImmersiveOverlay(duration: duration, fadeIn: fadeIn))
    }
}

/// Animates an overlay dismissal so the content fades out instead of cutting.
/// Kept a touch slower than a snap so the exit never feels abrupt.
func dismissImmersive(_ action: @escaping () -> Void, duration: Double = 0.5) {
    withAnimation(.easeOut(duration: max(duration * 0.8, 0.22))) { action() }
}
