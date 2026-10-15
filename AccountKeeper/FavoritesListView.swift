//
//  FavoritesListView.swift
//  BiliBili
//
//  My favorites folders & videos
//

import SwiftUI

struct FavoritesListView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var folders: [FavoriteFolder] = []
    @State private var selectedFolder: FavoriteFolder?
    @State private var videos: [Video] = []
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = true
    @State private var isLoadingMore = false
    @State private var total = 0
    @State private var selectedVideo: Video?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.biliBackground.ignoresSafeArea()
                if selectedFolder == nil {
                    folderList
                } else {
                    videoList
                }
            }
            .navigationTitle(selectedFolder?.title ?? "我的收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedFolder != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedFolder = nil
                            videos = []
                        } label: {
                            Image(systemName: "chevron.left").foregroundColor(.biliBlue)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundColor(.biliBlue)
                }
            }
            .overlay {
                if let video = selectedVideo {
                    VideoPlayerView(video: video, onDismiss: { selectedVideo = nil })
                        .environmentObject(store)
                        .ignoresSafeArea()
                        .zIndex(10)
                }
            }
            .onAppear { loadFolders() }
        }
    }

    private var folderList: some View {
        Group {
            if folders.isEmpty {
                ContentUnavailableView("暂无收藏夹", systemImage: "star",
                    description: Text("登录后可查看收藏夹内容"))
            } else {
                List {
                    ForEach(folders) { folder in
                        Button {
                            selectedFolder = folder
                            loadVideos(for: folder)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.biliBlue.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.biliBlue)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.title).font(.subheadline).foregroundStyle(.primary)
                                    Text("\(folder.count) 个视频").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var videoList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(videos) { video in
                    VideoCardView(video: video)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedVideo = video }
                        .onAppear {
                            if video.id == videos.last?.id, hasMore, !isLoadingMore {
                                loadMore()
                            }
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 20)
            if isLoadingMore { ProgressView().padding(.vertical, 12) }
        }
        .overlay {
            if isLoading && videos.isEmpty { ProgressView() }
        }
    }

    private func loadFolders() {
        BiliAPI.shared.fetchFavoriteFolders { folders in
            DispatchQueue.main.async { self.folders = folders }
        }
    }

    private func loadVideos(for folder: FavoriteFolder) {
        isLoading = true
        page = 1
        hasMore = true
        videos = []
        BiliAPI.shared.fetchFavoriteVideos(mediaId: folder.id, page: page) { newVideos, total in
            DispatchQueue.main.async {
                videos = newVideos
                self.total = total
                isLoading = false
                if newVideos.isEmpty || videos.count >= total { hasMore = false }
                else { page += 1 }
            }
        }
    }

    private func loadMore() {
        guard let folder = selectedFolder else { return }
        isLoadingMore = true
        BiliAPI.shared.fetchFavoriteVideos(mediaId: folder.id, page: page) { newVideos, total in
            DispatchQueue.main.async {
                videos.append(contentsOf: newVideos)
                isLoadingMore = false
                if newVideos.isEmpty || videos.count >= total { hasMore = false }
                else { page += 1 }
            }
        }
    }
}
