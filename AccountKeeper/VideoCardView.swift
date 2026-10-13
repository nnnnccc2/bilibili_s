//
//  VideoCardView.swift
//  BiliBili
//
//  Reusable video card matching reference design
//

import SwiftUI

struct VideoCardView: View {
    let video: Video
    var onTapUP主: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "play.rectangle")
                                    .foregroundStyle(.secondary)
                            )
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .overlay(ProgressView().scaleEffect(0.8))
                    @unknown default:
                        Rectangle().fill(Color.gray.opacity(0.15))
                    }
                }
                .aspectRatio(16.0/9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()

                if video.duration > 0 {
                    Text(video.durationText)
                        .font(.system(size: 10))
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(8)
                } else if video.category == "直播" {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(.red)
                            .frame(width: 5, height: 5)
                        Text("直播中")
                            .font(.system(size: 10))
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(8)
                }
            }

            // Title (2 lines)
            Text(video.title)
                .font(.system(size: 13))
                .fontWeight(.medium)
                .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
                .lineLimit(2)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)

            // UP主 avatar + name + views + danmaku + date
            HStack(spacing: 6) {
                if !video.upAvatar.isEmpty {
                    AsyncImage(url: URL(string: video.upAvatar)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 14, height: 14)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Text(video.upName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(video.viewsText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTapUP主?()
            }
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .onAppear {
            // Prefetch stream URL when card becomes visible so playback starts instantly on tap
            BiliAPI.shared.prefetchStreamURL(for: video)
        }
    }
}
