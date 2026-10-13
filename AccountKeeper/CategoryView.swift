//
//  CategoryView.swift
//  BiliBili
//
//  Site partitions / categories page
//

import SwiftUI

struct CategoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedPartition: Partition?
    @State private var partitionVideos: [Video] = []
    @State private var isLoading = false
    @State private var selectedVideo: Video?

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                if selectedPartition == nil {
                    // Partition grid
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(Partition.allCases) { p in
                            Button {
                                selectedPartition = p
                                loadPartition(p)
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.pink.opacity(0.12))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: p.icon)
                                            .font(.title2)
                                            .foregroundStyle(Color.pink)
                                    }
                                    Text(p.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                } else {
                    // Partition video list
                    if isLoading {
                        ProgressView().padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(partitionVideos) { video in
                                VideoCardView(video: video)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedVideo = video }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedPartition != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedPartition = nil
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text(selectedPartition?.rawValue ?? "分区")
                        .font(.title3).fontWeight(.bold)
                }
            }
            .sheet(item: $selectedVideo) { video in
                VideoPlayerView(video: video).environmentObject(store)
            }
        }
    }

    private func loadPartition(_ p: Partition) {
        isLoading = true
        BiliAPI.shared.fetchPartition(p) { raw in
            let filtered = store.applyFilter(raw)
            DispatchQueue.main.async {
                partitionVideos = filtered
                isLoading = false
            }
        }
    }
}
