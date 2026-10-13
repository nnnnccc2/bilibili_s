//
//  VideoCardView.swift
//  BiliBili
//
//  Reusable two-column video card
//

import SwiftUI

struct VideoCardView: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover with duration badge
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
                            .overlay(ProgressView())
                    @unknown default:
                        Rectangle().fill(Color.gray.opacity(0.15))
                    }
                }
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if video.duration > 0 {
                    Text(video.durationText)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                } else {
                    // Live indicator
                    HStack(spacing: 3) {
                        Circle()
                            .fill(.red)
                            .frame(width: 5, height: 5)
                        Text("直播中")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
                }
            }

            // Title (2 lines)
            Text(video.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // UP主 & stats
            HStack(spacing: 4) {
                Image(systemName: "play.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(video.viewsText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
                Image(systemName: "person.crop.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(video.upName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
