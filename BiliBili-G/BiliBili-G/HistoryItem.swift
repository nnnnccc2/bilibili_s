//
//  HistoryItem.swift
//  BiliBili
//
//  Watch history record
//

import Foundation

struct HistoryItem: Identifiable, Codable, Hashable {
    var id: String          // unique history id
    var videoId: String     // bvid
    var title: String
    var cover: String
    var upName: String
    var duration: Int
    var progress: Int       // watched position in seconds
    var watchedAt: Date

    init(id: String = UUID().uuidString,
         videoId: String,
         title: String,
         cover: String,
         upName: String,
         duration: Int,
         progress: Int = 0,
         watchedAt: Date = Date()) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.cover = cover
        self.upName = upName
        self.duration = duration
        self.progress = progress
        self.watchedAt = watchedAt
    }

    var progressText: String {
        if duration == 0 { return "" }
        let percent = Int(Double(progress) / Double(duration) * 100)
        if percent >= 95 { return "已看完" }
        return "看到 \(formatTime(progress))"
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
