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
    @State private var showingSearch = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(showingSearch: $showingSearch)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("首页")
                }
                .tag(0)

            FollowingView(showingSearch: $showingSearch)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("关注")
                }
                .tag(1)

            CategoryView(showingSearch: $showingSearch)
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("分区")
                }
                .tag(2)

            ProfileView(showingSearch: $showingSearch)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我的")
                }
                .tag(3)
        }
        .tint(.pink)
        .sheet(isPresented: $showingSearch) {
            SearchView().environmentObject(store)
        }
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
