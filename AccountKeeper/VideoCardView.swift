//
//  VideoCardView.swift
//  BiliBili
//
//  Reusable video card matching the reference design
//  (translucent card, 16:9 cover with duration badge, two-line meta)
//

import SwiftUI

struct VideoCardView: View {
    let video: Video
    var onTapUP主: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover (16:9) with duration badge
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: video.cover)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color.biliMutedSurface)
                            .overlay(
                                Image(systemName: "play.rectangle")
                                    .foregroundStyle(.secondary)
                            )
                    case .empty:
                        Rectangle()
                            .fill(Color.biliMutedSurface)
                            .overlay(ProgressView().scaleEffect(0.8))
                    @unknown default:
                        Rectangle().fill(Color.biliMutedSurface)
                    }
                }
                .aspectRatio(16.0/9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()

                if video.duration > 0 {
                    Text(video.durationText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.biliText.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(8)
                } else if video.category == "直播" {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(.red)
                            .frame(width: 5, height: 5)
                        Text("直播中")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                // Title (2 lines)
                Text(video.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.biliText)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Row 1: avatar + uploader name
                HStack(spacing: 6) {
                    upAvatar
                    Text(video.upName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.biliSubtext)
                        .lineLimit(1)
                }
                .padding(.top, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapUP主?()
                }

                // Row 2: views · danmaku · publish time
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                        Text(video.viewsText)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "message.fill")
                        Text(video.danmakuText)
                    }

                    Spacer(minLength: 4)

                    if !video.publishTime.isEmpty {
                        Text(video.publishTime)
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.biliSubtext)
                .padding(.top, 6)
            }
            .padding(10)
        }
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .onAppear {
            // Prefetch stream URL when card becomes visible so playback starts instantly on tap
            BiliAPI.shared.prefetchStreamURL(for: video)
        }
    }

    @ViewBuilder
    private var upAvatar: some View {
        if !video.upAvatar.isEmpty {
            AsyncImage(url: URL(string: video.upAvatar)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(Color.biliMutedSurface)
                }
            }
            .frame(width: 14, height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}
