//
//  CategoryView.swift
//  BiliBili
//
//  Site partitions / categories page
//

import SwiftUI

struct CategoryView: View {
    @EnvironmentObject var store: AppStore
    @Binding var showingSearch: Bool
    @State private var selectedPartition: Partition?
    @State private var partitionVideos: [Video] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var page = 1
    @State private var hasMore = true
    @State private var selectedVideo: Video?
    @State private var selectedUPMid: Int = 0
    @State private var selectedUPName: String = ""
    @State private var showingUPSpace = false
    @Namespace private var playerZoom

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                biliBackgroundGradient.ignoresSafeArea()
                ScrollView {
                    if selectedPartition == nil {
                        // Header: 全站分区 + subtitle + badge
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("全站分区")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Text("Bilibili 官方分类频道 · 实时净化过滤")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255))
                                    Text("官方分区接口")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground).opacity(0.7))
                                .clipShape(Capsule())
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        // Partition grid — rounded square cards with icon + label
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Partition.allCases) { p in
                                Button {
                                    selectedPartition = p
                                    loadPartition(p)
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(Color.white.opacity(0.85))
                                                .frame(height: 72)
                                            Image(systemName: p.icon)
                                                .font(.system(size: 26, weight: .medium))
                                                .foregroundStyle(Color.biliBlue)
                                        }
                                        Text(p.rawValue)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    } else {
                        // Partition video list
                        if isLoading {
                            ProgressView().padding(.top, 60)
                        } else if partitionVideos.isEmpty {
                            ContentUnavailableView(
                                "暂无内容",
                                systemImage: "tray",
                                description: Text("该分区暂无视频，试试其他分区")
                            )
                            .padding(.top, 60)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(partitionVideos) { video in
                                    VideoCardView(
                                        video: video,
                                        onTap: { selectedVideo = video },
                                        onTapUP主: {
                                            if video.upMid > 0 {
                                                selectedUPMid = video.upMid
                                                selectedUPName = video.upName
                                                showingUPSpace = true
                                            }
                                        }
                                    )
                                        .matchedTransitionSource(id: video.id, in: playerZoom)
                                        .onAppear {
                                            if video.id == partitionVideos.last?.id, hasMore, !isLoadingMore {
                                                loadPartition(selectedPartition, reset: false)
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .padding(.bottom, 24)

                            if isLoadingMore {
                                ProgressView().padding(.vertical, 12)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedPartition != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedPartition = nil
                            partitionVideos = []
                            page = 1
                            hasMore = true
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.biliBlue)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text(selectedPartition?.rawValue ?? "分区")
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
            // 播放器：系统全屏模态 + iOS 18 zoom 转场。
            .fullScreenCover(item: $selectedVideo) { video in
                VideoPlayerView(video: video, onDismiss: { selectedVideo = nil })
                    .environmentObject(store)
                    .ignoresSafeArea()
                    .navigationTransition(.zoom(sourceID: video.id, in: playerZoom))
                    .presentationBackground(.black)
            }
            // UP 空间：系统全屏模态。
            .fullScreenCover(isPresented: $showingUPSpace) {
                if selectedUPMid > 0 {
                    UPSpaceView(mid: selectedUPMid, initialName: selectedUPName, onDismiss: { showingUPSpace = false })
                        .environmentObject(store)
                }
            }
        }
    }

    private func loadPartition(_ p: Partition?, reset: Bool = true) {
        guard let p = p else { return }
        if reset {
            page = 1
            hasMore = true
            isLoading = true
            partitionVideos = []
        } else {
            guard hasMore, !isLoadingMore else { return }
            isLoadingMore = true
        }
        BiliAPI.shared.fetchPartition(p, page: page) { raw in
            DispatchQueue.main.async {
                let filtered = store.applyFilter(raw)
                if reset {
                    partitionVideos = filtered
                    isLoading = false
                } else {
                    for v in filtered where !partitionVideos.contains(where: { $0.id == v.id }) {
                        partitionVideos.append(v)
                    }
                    isLoadingMore = false
                }
                if filtered.isEmpty {
                    hasMore = false
                } else {
                    page += 1
                }
            }
        }
    }
}
