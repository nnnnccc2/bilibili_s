//
//  Video.swift
//  BiliBili
//
//  Video data model
//

import Foundation

struct Video: Identifiable, Codable, Hashable {
    var id: String              // bvid
    var aid: Int                // av number, 0 if unknown
    var title: String
    var cover: String           // cover image URL
    var duration: Int           // duration in seconds
    var upName: String
    var upMid: Int              // UP主 user ID (mid), 0 if unknown
    var upAvatar: String
    var views: Int
    var danmaku: Int
    var publishTime: String
    var category: String
    var tags: [String]
    var desc: String
    var likes: Int
    var coins: Int
    var favorites: Int
    var shares: Int
    var tid: Int                // Bilibili leaf partition id (0 if unknown)
    var copyright: Int          // 1=原创, 2=转载, 0=未知（用于识别搬运号/营销号）

    init(id: String = UUID().uuidString,
         aid: Int = 0,
         title: String = "",
         cover: String = "",
         duration: Int = 0,
         upName: String = "",
         upMid: Int = 0,
         upAvatar: String = "",
         views: Int = 0,
         danmaku: Int = 0,
         publishTime: String = "",
         category: String = "",
         tags: [String] = [],
         desc: String = "",
         likes: Int = 0,
         coins: Int = 0,
         favorites: Int = 0,
         shares: Int = 0,
         tid: Int = 0,
         copyright: Int = 0) {
        self.id = id
        self.aid = aid
        self.title = title
        self.cover = cover
        self.duration = duration
        self.upName = upName
        self.upMid = upMid
        self.upAvatar = upAvatar
        self.views = views
        self.danmaku = danmaku
        self.publishTime = publishTime
        self.category = category
        self.tags = tags
        self.desc = desc
        self.likes = likes
        self.coins = coins
        self.favorites = favorites
        self.shares = shares
        self.tid = tid
        self.copyright = copyright
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

    /// Formatted danmaku count e.g. "4.3万"
    var danmakuText: String {
        if danmaku >= 10000 {
            return String(format: "%.1f万", Double(danmaku) / 10000.0)
        }
        return "\(danmaku)"
    }
}

/// UP主 space profile info
struct UPSpaceInfo {
    let mid: Int
    let name: String
    let avatar: String
    let sign: String
    let level: Int
    let fans: Int
    let following: Int
    let likes: Int  // 获赞数
    let archiveCount: Int  // 视频总数
}

/// Reason a video was blocked by the filter engine
enum BlockReason: String, Codable, CaseIterable {
    case clickbait = "标题党/引导词"
    case japaneseTitle = "日语标题"
    case japaneseUP = "UP主含日文字符"
    case duration = "时长过短"
    case insultWord = "命中侮辱贬低词"
    case exclamationSpam = "标题感叹号过多"
    case badData = "无封面/无视频"
    case categoryBlocked = "分类黑名单"
    case upBlocked = "UP主黑名单"
    case keywordBlocked = "命中关键词"
    case tagBlocked = "命中标签(Tag)"
    case partitionBlocked = "分区屏蔽"
    case creatorTypeBlocked = "博主类型屏蔽"

    var icon: String {
        switch self {
        case .clickbait: return "exclamationmark.triangle"
        case .japaneseTitle: return "character.book.closed"
        case .japaneseUP: return "person.crop.circle.badge.xmark"
        case .duration: return "timer"
        case .insultWord: return "hand.raised"
        case .exclamationSpam: return "text.badge.exclamationmark"
        case .badData: return "photo.badge.exclamationmark"
        case .categoryBlocked: return "folder.badge.minus"
        case .upBlocked: return "person.badge.minus"
        case .keywordBlocked: return "text.magnifyingglass"
        case .tagBlocked: return "tag.slash"
        case .partitionBlocked: return "square.grid.2x2"
        case .creatorTypeBlocked: return "person.2.slash"
        }
    }
}
