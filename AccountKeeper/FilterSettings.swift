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
    var byExclamationSpam: Int = 0
    var byBadData: Int = 0
    var byCategory: Int = 0
    var byUPBlocked: Int = 0
    var byKeyword: Int = 0

    mutating func add(_ reason: BlockReason) {
        totalBlocked += 1
        switch reason {
        case .clickbait: byClickbait += 1
        case .japaneseTitle: byJapaneseTitle += 1
        case .japaneseUP: byJapaneseUP += 1
        case .duration: byDuration += 1
        case .insultWord: byInsultWord += 1
        case .exclamationSpam: byExclamationSpam += 1
        case .badData: byBadData += 1
        case .categoryBlocked: byCategory += 1
        case .upBlocked: byUPBlocked += 1
        case .keywordBlocked: byKeyword += 1
        }
    }

    /// Backwards-compatible decoding so old persisted stats without new counters still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalBlocked = try container.decodeIfPresent(Int.self, forKey: .totalBlocked) ?? 0
        byClickbait = try container.decodeIfPresent(Int.self, forKey: .byClickbait) ?? 0
        byJapaneseTitle = try container.decodeIfPresent(Int.self, forKey: .byJapaneseTitle) ?? 0
        byJapaneseUP = try container.decodeIfPresent(Int.self, forKey: .byJapaneseUP) ?? 0
        byDuration = try container.decodeIfPresent(Int.self, forKey: .byDuration) ?? 0
        byInsultWord = try container.decodeIfPresent(Int.self, forKey: .byInsultWord) ?? 0
        byExclamationSpam = try container.decodeIfPresent(Int.self, forKey: .byExclamationSpam) ?? 0
        byBadData = try container.decodeIfPresent(Int.self, forKey: .byBadData) ?? 0
        byCategory = try container.decodeIfPresent(Int.self, forKey: .byCategory) ?? 0
        byUPBlocked = try container.decodeIfPresent(Int.self, forKey: .byUPBlocked) ?? 0
        byKeyword = try container.decodeIfPresent(Int.self, forKey: .byKeyword) ?? 0
    }
}

/// Global filter configuration
struct FilterSettings: Codable, Hashable {
    // Title / clickbait filtering
    var enableClickbaitFilter: Bool = true
    var enableExclamationFilter: Bool = false
    var enableJapaneseTitleFilter: Bool = true

    // UP主 filtering
    var enableJapaneseUPFilter: Bool = true

    // Insult / derogatory word filtering
    var enableInsultWordFilter: Bool = true
    var builtInWordsEnabled: Bool = true
    var customBlockedWords: [String] = []

    // Duration filtering (global, applies to home/feed/category/dynamic)
    // Multi-select: videos whose duration is <= ANY selected threshold are blocked.
    // If empty, no duration filtering.
    // Default: only 10s pre-selected — wider defaults hid too much normal content.
    var blockedDurationSeconds: Set<Int> = [10]

    // Search-specific duration filter (min duration for search results)
    var searchMinDurationSeconds: Int? = nil

    // Category filtering
    var enableCategoryFilter: Bool = false
    var blockedCategories: Set<String> = []

    // UP主 blacklist filtering
    var enableUPBlockFilter: Bool = false
    var blockedUPMids: Set<Int> = []

    // General keyword filtering
    var enableKeywordFilter: Bool = false
    var blockedKeywords: [String] = []
    var builtInKeywordsEnabled: Bool = false

    // UI
    var showFilteredBanner: Bool = true

    /// Schema version used to migrate previously-persisted aggressive defaults.
    /// Optional so that settings saved by older builds (without this key) still decode.
    var schemaVersion: Int? = nil

    var stats: FilterStats = FilterStats()

    /// Current filter-settings schema version.
    static let currentSchemaVersion = 3

    /// Backwards-compatible decoding so new fields default safely when missing from old persisted settings.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enableClickbaitFilter = try container.decodeIfPresent(Bool.self, forKey: .enableClickbaitFilter) ?? true
        enableExclamationFilter = try container.decodeIfPresent(Bool.self, forKey: .enableExclamationFilter) ?? false
        enableJapaneseTitleFilter = try container.decodeIfPresent(Bool.self, forKey: .enableJapaneseTitleFilter) ?? true
        enableJapaneseUPFilter = try container.decodeIfPresent(Bool.self, forKey: .enableJapaneseUPFilter) ?? true
        enableInsultWordFilter = try container.decodeIfPresent(Bool.self, forKey: .enableInsultWordFilter) ?? true
        builtInWordsEnabled = try container.decodeIfPresent(Bool.self, forKey: .builtInWordsEnabled) ?? true
        customBlockedWords = try container.decodeIfPresent([String].self, forKey: .customBlockedWords) ?? []
        blockedDurationSeconds = try container.decodeIfPresent(Set<Int>.self, forKey: .blockedDurationSeconds) ?? [10]
        searchMinDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .searchMinDurationSeconds)
        enableCategoryFilter = try container.decodeIfPresent(Bool.self, forKey: .enableCategoryFilter) ?? false
        blockedCategories = try container.decodeIfPresent(Set<String>.self, forKey: .blockedCategories) ?? []
        enableUPBlockFilter = try container.decodeIfPresent(Bool.self, forKey: .enableUPBlockFilter) ?? false
        blockedUPMids = try container.decodeIfPresent(Set<Int>.self, forKey: .blockedUPMids) ?? []
        enableKeywordFilter = try container.decodeIfPresent(Bool.self, forKey: .enableKeywordFilter) ?? false
        blockedKeywords = try container.decodeIfPresent([String].self, forKey: .blockedKeywords) ?? []
        builtInKeywordsEnabled = try container.decodeIfPresent(Bool.self, forKey: .builtInKeywordsEnabled) ?? false
        showFilteredBanner = try container.decodeIfPresent(Bool.self, forKey: .showFilteredBanner) ?? true
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
        stats = try container.decodeIfPresent(FilterStats.self, forKey: .stats) ?? FilterStats()
    }
}

// MARK: - Built-in word lists

extension FilterSettings {
    /// Clickbait / leading title keywords (含 ! / !! / !!! 连续感叹号)
    static let builtInClickbaitWords: [String] = [
        "疯了", "炸了", "屌爆了", "惊呆了", "吓尿了", "千万别看",
        "震惊", "卧槽", "绝了", "太牛了", "神了",
        "逆天", "离谱", "破防了", "泪目", "绷不住了",
        "看完沉默", "不看后悔", "太可怕了", "太离谱了",
        "千万别买", "千万不要", "万万没想到",
        "99%的人", "所有人都", "强烈推荐",
        "一秒入坑", "笑不活了", "人傻了", "直接封神"
    ]

    /// 感叹号拦截词（半角 + 全角；中文标题多用全角 ！）
    static let exclamationWords: [String] = [
        "!!!", "!!", "!",
        "！！！", "！！", "！"
    ]

    /// Insulting / derogatory word list (built-in core 32 words)
    static let builtInInsultWords: [String] = [
        "弱智", "脑残", "煞笔", "傻逼", "沙雕", "蠢货", "低能", "白痴",
        "贱人", "nt", "sb", "nc", "孤儿", "死全家", "没妈", "狗都不看",
        "垃圾UP", "小丑", "下头", "恶心", "晦气", "滚出", "闭嘴", "智障",
        "废物", "无脑", "狗屎", "装逼", "骗子", "恰烂饭", "黑料", "翻车塌房"
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

    /// General built-in keyword suggestions for blocking anime / gaming / food / vlog content.
    /// These are opt-in via `builtInKeywordsEnabled` and are not enforced by default.
    static let builtInKeywords: [String] = [
        "动画", "动漫", "日本动画", "二次元", "游戏", "录播",
        "美食", "吃播", "影视", "电影", "电视剧", "综艺",
        "Vlog", "日常", "挑战", "鬼畜", "吐槽", "reaction"
    ]

    /// All currently active general keywords (built-in if enabled + custom keywords).
    var activeKeywords: [String] {
        var words: [String] = []
        if builtInKeywordsEnabled {
            words.append(contentsOf: FilterSettings.builtInKeywords)
        }
        words.append(contentsOf: blockedKeywords)
        return words
    }
}

// MARK: - Duration options

extension FilterSettings {
    /// Global duration-block options (settings page) — multi-select
    static let durationBlockOptions: [(label: String, seconds: Int)] = [
        ("10秒", 10),
        ("28秒", 28),
        ("30秒", 30),
        ("1分钟", 60),
        ("2分钟", 120),
        ("3分钟", 180),
        ("4分钟", 240),
        ("5分钟", 300),
        ("6分钟", 360),
        ("7分钟", 420),
        ("8分钟", 480),
        ("9分钟", 540),
        ("10分钟", 600),
        ("12分钟", 720),
        ("14分钟", 840),
        ("15分钟", 900),
        ("20分钟", 1200),
        ("30分钟", 1800),
        ("40分钟", 2400),
        ("60分钟", 3600),
        ("2小时", 7200)
    ]

    /// Effective global duration block threshold = max of all selected durations.
    /// A video with duration <= this value is blocked. nil means no duration filter.
    var effectiveDurationThreshold: Int? {
        blockedDurationSeconds.max()
    }

    /// Search duration filter options (search result page).
    /// IMPORTANT: every `seconds` value must be unique — the selected index is
    /// resolved by matching `seconds`, so duplicate values make one chip
    /// unselectable (e.g. "60 秒以上" collided with "1 分钟以上").
    static let searchDurationOptions: [(label: String, seconds: Int?)] = [
        ("全部时长", nil),
        ("10 秒以上", 10),
        ("20 秒以上", 20),
        ("30 秒以上", 30),
        ("40 秒以上", 40),
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
