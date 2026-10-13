//
//  ContentView.swift
//  BiliBili
//
//  Main tab container with bottom navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("首页")
                }
                .tag(0)

            FollowingView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("关注")
                }
                .tag(1)

            CategoryView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("分区")
                }
                .tag(2)

            SearchView()
                .tabItem {
                    // Prominent circular, slightly dark translucent search button
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .padding(8)
                        .background(Circle().fill(.ultraThinMaterial).opacity(0.9))
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我的")
                }
                .tag(4)
        }
        .tint(.pink)
        .onAppear {
            // Style the tab bar
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
