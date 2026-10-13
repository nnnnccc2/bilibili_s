//
//  Video.swift
//  BiliBili
//
//  Video data model
//

import Foundation

struct Video: Identifiable, Codable, Hashable {
    var id: String              // bvid
    var title: String
    var cover: String           // cover image URL
    var duration: Int           // duration in seconds
    var upName: String
    var upAvatar: String
    var views: Int
    var danmaku: Int
    var publishTime: String
    var category: String
    var desc: String
    var likes: Int
    var coins: Int
    var favorites: Int
    var shares: Int

    init(id: String = UUID().uuidString,
         title: String = "",
         cover: String = "",
         duration: Int = 0,
         upName: String = "",
         upAvatar: String = "",
         views: Int = 0,
         danmaku: Int = 0,
         publishTime: String = "",
         category: String = "",
         desc: String = "",
         likes: Int = 0,
         coins: Int = 0,
         favorites: Int = 0,
         shares: Int = 0) {
        self.id = id
        self.title = title
        self.cover = cover
        self.duration = duration
        self.upName = upName
        self.upAvatar = upAvatar
        self.views = views
        self.danmaku = danmaku
        self.publishTime = publishTime
        self.category = category
        self.desc = desc
        self.likes = likes
        self.coins = coins
        self.favorites = favorites
        self.shares = shares
    }

    /// Formatted duration string e.g. "06:28", "02:02:00"
    var durationText: String {
        let h = duration / 3600
        let m = (duration % 3600) / 60
        let s = duration % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// Formatted view count e.g. "182.0万"
    var viewsText: String {
        if views >= 10000 {
            return String(format: "%.1f万", Double(views) / 10000.0)
        }
        return "\(views)"
    }
}

/// Reason a video was blocked by the filter engine
enum BlockReason: String, Codable, CaseIterable {
    case clickbait = "标题党/引导词"
    case japaneseTitle = "日语标题"
    case japaneseUP = "UP主含日文字符"
    case duration = "时长过短"
    case insultWord = "命中侮辱贬低词"

    var icon: String {
        switch self {
        case .clickbait: return "exclamationmark.triangle"
        case .japaneseTitle: return "character.book.closed"
        case .japaneseUP: return "person.crop.circle.badge.xmark"
        case .duration: return "timer"
        case .insultWord: return "hand.raised"
        }
    }
}
