//
//  FollowingView.swift
//  BiliBili
//
//  Following / dynamic feed page
//

import SwiftUI

struct FollowingView: View {
    @EnvironmentObject var store: AppStore
    @Binding var showingSearch: Bool
    @State private var selectedTab: FollowTab = .all
    @State private var videos: [Video] = []
    @State private var isLoading = false
    @State private var selectedVideo: Video?

    enum FollowTab: String, CaseIterable, Identifiable {
        case all = "综合"
        case video = "视频"
        case bangumi = "追番"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tabs
                HStack(spacing: 24) {
                    ForEach(FollowTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack(spacing: 4) {
                                Text(tab.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == tab ? .bold : .regular)
                                    .foregroundStyle(selectedTab == tab ? Color.pink : .secondary)
                                if selectedTab == tab {
                                    Capsule().fill(Color.pink).frame(width: 18, height: 3)
                                } else {
                                    Capsule().fill(Color.clear).frame(width: 18, height: 3)
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if store.settings.showFilteredBanner && store.lastBlockedCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled").foregroundStyle(.green)
                        Text("已净化 \(store.lastBlockedCount) 条低质内容")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal).padding(.vertical, 6)
                    .background(Color.green.opacity(0.08))
                }

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if videos.isEmpty {
                    ContentUnavailableView("暂无动态", systemImage: "heart",
                        description: Text("关注的UP主还没有发布新内容"))
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(videos) { video in
                                VideoCardView(video: video)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedVideo = video }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("关注")
                        .font(.title3).fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(8)
                            .background(Circle().fill(.ultraThinMaterial).opacity(0.9))
                    }
                }
            }
            .sheet(item: $selectedVideo) { video in
                VideoPlayerView(video: video).environmentObject(store)
            }
        }
        .onAppear { if videos.isEmpty { load() } }
    }

    private func load() {
        isLoading = true
        BiliAPI.shared.fetchFollowing { raw in
            let filtered = store.applyFilter(raw)
            DispatchQueue.main.async {
                videos = filtered
                isLoading = false
            }
        }
    }
}
