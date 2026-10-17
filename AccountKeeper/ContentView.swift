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
        .animation(.timingCurve(0.165, 0.84, 0.44, 1.0, duration: 0.34), value: store.immersiveDepth)
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
/// The motion is crisp but alive ("干练" + "像水一样有生命"): the overlay starts a
/// touch *larger* than the screen (1.025 → 1.0) so it settles into place without
/// ever pulling back from the edges — scaling below 1.0 used to flash a white
/// border and jump the notch colour — and it leaves by expanding very slightly
/// (1.0 → 1.03) as it fades. Both use sharp cubic curves instead of `easeInOut`,
/// whose slow ramp-up read as sluggish and lifeless.
///
/// The entrance is driven by internal state, so it works even when the call-site
/// doesn't wrap its state change in `withAnimation`; the exit uses an
/// opacity+scale removal transition animated by `dismissImmersive`.
struct ImmersiveOverlay: ViewModifier {
    @EnvironmentObject var store: AppStore
    var duration: Double = 0.34
    @State private var appeared = false

    /// Quick, confident start; soft landing (≈ easeOutQuart).
    private var enterCurve: Animation {
        .timingCurve(0.165, 0.84, 0.44, 1.0, duration: duration)
    }

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 1.025)
            .transition(.asymmetric(
                insertion: .identity,
                removal: .opacity.combined(with: .scale(scale: 1.03))))
            .onAppear {
                store.pushImmersive()
                withAnimation(enterCurve) { appeared = true }
            }
            .onDisappear { store.popImmersive() }
    }
}

extension View {
    func immersive(duration: Double = 0.34) -> some View {
        modifier(ImmersiveOverlay(duration: duration))
    }
}

/// Animates an overlay dismissal so it leaves gracefully instead of cutting.
func dismissImmersive(_ action: @escaping () -> Void, duration: Double = 0.26) {
    // Gentle start, quick exit (≈ easeInCubic) — it lets go of the screen at
    // once instead of hanging around.
    withAnimation(.timingCurve(0.55, 0.06, 0.68, 0.19, duration: duration)) { action() }
}
