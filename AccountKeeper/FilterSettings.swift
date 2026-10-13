//
//  FilterSettings.swift
//  BiliBili
//
//  Filter configuration, built-in word lists, and statistics
//

import Foundation

/// Statistics for the purification engine
struct FilterStats: Codable, Hashable {
    var totalBlocked: Int = 0
    var byClickbait: Int = 0
    var byJapaneseTitle: Int = 0
    var byJapaneseUP: Int = 0
    var byDuration: Int = 0
    var byInsultWord: Int = 0

    mutating func add(_ reason: BlockReason) {
        totalBlocked += 1
        switch reason {
        case .clickbait: byClickbait += 1
        case .japaneseTitle: byJapaneseTitle += 1
        case .japaneseUP: byJapaneseUP += 1
        case .duration: byDuration += 1
        case .insultWord: byInsultWord += 1
        }
    }
}

/// Global filter configuration
struct FilterSettings: Codable, Hashable {
    // Title / clickbait filtering
    var enableClickbaitFilter: Bool = true
    var enableJapaneseTitleFilter: Bool = true

    // UP主 filtering
    var enableJapaneseUPFilter: Bool = true

    // Insult / derogatory word filtering
    var enableInsultWordFilter: Bool = true
    var builtInWordsEnabled: Bool = true
    var customBlockedWords: [String] = []

    // Duration filtering (global, applies to home/feed/category/dynamic)
    // When set, videos with duration <= threshold are blocked
    var durationThresholdSeconds: Int? = nil

    // Search-specific duration filter (min duration for search results)
    var searchMinDurationSeconds: Int? = nil

    // UI
    var showFilteredBanner: Bool = true

    var stats: FilterStats = FilterStats()
}

// MARK: - Built-in word lists

extension FilterSettings {
    /// Clickbait / leading title keywords (e.g. 疯了、炸了、屌爆了、！、惊呆了 etc.)
    static let builtInClickbaitWords: [String] = [
        "疯了", "炸了", "屌爆了", "惊呆了", "吓尿了", "千万别看",
        "震惊", "卧槽", "我去", "绝了", "太牛了", "神了",
        "逆天", "离谱", "破防了", "泪目", "绷不住了",
        "！！！", "！！", "！",
        "看完沉默", "不看后悔", "太可怕了", "太离谱了",
        "千万别买", "千万不要", "竟然", "居然", "万万没想到",
        "99%的人", "所有人都", "必看", "强烈推荐",
        "一秒入坑", "笑不活了", "人傻了", "直接封神"
    ]

    /// Insulting / derogatory word list (built-in core 32 words)
    static let builtInInsultWords: [String] = [
        "脑残", "傻逼", "弱智", "废物", "垃圾人", "人渣",
        "败类", "蠢货", "白痴", "智障", "脑残粉", "黑子",
        "喷子", "杠精", "键盘侠", "恶臭", "恶心", "龌龊",
        "卑鄙", "无耻", "下流", "肮脏", "下贱", "不要脸",
        "狗东西", "兔崽子", "王八蛋", "混蛋", "混账", "该死",
        "去死", "滚蛋", "滚犊子", "废物点心"
    ]

    /// All currently active blocked words (built-in insult words if enabled + custom words)
    var activeInsultWords: [String] {
        var words: [String] = []
        if builtInWordsEnabled {
            words.append(contentsOf: FilterSettings.builtInInsultWords)
        }
        words.append(contentsOf: customBlockedWords)
        return words
    }
}

// MARK: - Duration options

extension FilterSettings {
    /// Global duration-block options (settings page)
    static let durationBlockOptions: [(label: String, seconds: Int?)] = [
        ("不限制", nil),
        ("10 秒", 10),
        ("28 秒", 28),
        ("30 秒", 30),
        ("1 分钟", 60),
        ("2 分钟", 120),
        ("3 分钟", 180),
        ("4 分钟", 240),
        ("5 分钟", 300),
        ("6 分钟", 360),
        ("7 分钟", 420),
        ("8 分钟", 480),
        ("9 分钟", 540),
        ("10 分钟", 600),
        ("12 分钟", 720),
        ("14 分钟", 840),
        ("15 分钟", 900)
    ]

    /// Search duration filter options (search result page)
    static let searchDurationOptions: [(label: String, seconds: Int?)] = [
        ("全部时长", nil),
        ("10 秒以上", 10),
        ("20 秒以上", 20),
        ("30 秒以上", 30),
        ("40 秒以上", 40),
        ("60 秒以上", 60),
        ("1 分钟以上", 60),
        ("2 分钟以上", 120),
        ("4 分钟以上", 240),
        ("6 分钟以上", 360),
        ("10 分钟以上", 600),
        ("15 分钟以上", 900),
        ("20 分钟以上", 1200),
        ("30 分钟以上", 1800),
        ("50 分钟以上", 3000),
        ("1 小时以上", 3600),
        ("2 小时以上", 7200)
    ]
}
