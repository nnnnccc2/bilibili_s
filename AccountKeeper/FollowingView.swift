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
    @State private var selectedUPMid: Int = 0
    @State private var selectedUPName: String = ""
    @State private var showingUPSpace = false

    enum FollowTab: String, CaseIterable, Identifiable {
        case all = "综合"
        case video = "视频"
        case bangumi = "追番"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                biliBackgroundGradient.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Tabs
                    HStack(spacing: 24) {
                        ForEach(FollowTab.allCases) { tab in
                            Button {
                                selectedTab = tab
                                load()
                            } label: {
                                VStack(spacing: 4) {
                                    Text(tab.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(selectedTab == tab ? .bold : .regular)
                                        .foregroundStyle(selectedTab == tab ? Color.biliBlue : .secondary)
                                    if selectedTab == tab {
                                        Capsule().fill(Color.biliBlue).frame(width: 18, height: 3)
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
                            Image(systemName: "shield.lefthalf.filled").foregroundColor(.biliBlue)
                            Text("已净化 \(store.lastBlockedCount) 条低质内容")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal).padding(.vertical, 6)
                        .background(Color.biliBlue.opacity(0.08))
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
                                    VideoCardView(video: video) {
                                        if video.upMid > 0 {
                                            selectedUPMid = video.upMid
                                            selectedUPName = video.upName
                                            showingUPSpace = true
                                        }
                                    }
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedVideo = video }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        }
                        .refreshable {
                            await loadAsync()
                        }
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
                            .foregroundColor(.biliBlue)
                            .padding(8)
                            .background(Circle().fill(.ultraThinMaterial).opacity(0.9))
                    }
                }
            }
        }
        .overlay {
            if let video = selectedVideo {
                VideoPlayerView(video: video, onDismiss: { selectedVideo = nil })
                    .environmentObject(store)
                    .ignoresSafeArea()
                    .immersive(opaque: true)
                    .id(video.id)
                    .zIndex(10)
            }
        }
        .overlay {
            if showingUPSpace, selectedUPMid > 0 {
                UPSpaceView(mid: selectedUPMid, initialName: selectedUPName, onDismiss: { showingUPSpace = false })
                    .environmentObject(store)
                    .immersive()
                    .zIndex(20)
            }
        }
        .onAppear { if videos.isEmpty { load() } }
    }

    private func load() {
        isLoading = true
        BiliAPI.shared.fetchFollowing { raw in
            DispatchQueue.main.async {
                let filtered = store.applyFilter(raw)
                videos = filtered
                isLoading = false
            }
        }
    }

    @Sendable
    private func loadAsync() async {
        await withCheckedContinuation { continuation in
            load()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                continuation.resume()
            }
        }
    }
}
