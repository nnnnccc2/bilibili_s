//
//  FilterSettings.swift
//  BiliBili
//
//  Filter configuration, built-in word lists, and statistics
//

import Foundation
import SwiftUI

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
    var byTag: Int = 0
    var byPartition: Int = 0
    var byCreatorType: Int = 0

    init() {}

    /// 逐字段 decodeIfPresent —— 旧版本存储的统计 JSON 缺少后加的字段时也能解码，
    /// 不会因为一个缺失字段丢掉整份统计。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalBlocked = try c.decodeIfPresent(Int.self, forKey: .totalBlocked) ?? 0
        byClickbait = try c.decodeIfPresent(Int.self, forKey: .byClickbait) ?? 0
        byJapaneseTitle = try c.decodeIfPresent(Int.self, forKey: .byJapaneseTitle) ?? 0
        byJapaneseUP = try c.decodeIfPresent(Int.self, forKey: .byJapaneseUP) ?? 0
        byDuration = try c.decodeIfPresent(Int.self, forKey: .byDuration) ?? 0
        byInsultWord = try c.decodeIfPresent(Int.self, forKey: .byInsultWord) ?? 0
        byExclamationSpam = try c.decodeIfPresent(Int.self, forKey: .byExclamationSpam) ?? 0
        byBadData = try c.decodeIfPresent(Int.self, forKey: .byBadData) ?? 0
        byCategory = try c.decodeIfPresent(Int.self, forKey: .byCategory) ?? 0
        byUPBlocked = try c.decodeIfPresent(Int.self, forKey: .byUPBlocked) ?? 0
        byKeyword = try c.decodeIfPresent(Int.self, forKey: .byKeyword) ?? 0
        byTag = try c.decodeIfPresent(Int.self, forKey: .byTag) ?? 0
        byPartition = try c.decodeIfPresent(Int.self, forKey: .byPartition) ?? 0
        byCreatorType = try c.decodeIfPresent(Int.self, forKey: .byCreatorType) ?? 0
    }

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
        case .tagBlocked: byTag += 1
        case .partitionBlocked: byPartition += 1
        case .creatorTypeBlocked: byCreatorType += 1
        }
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
    /// 被「关闭使用」的自定义屏蔽词：保留在列表中（变灰），但不参与过滤。
    var disabledWords: Set<String> = []

    // Duration filtering (global, applies to home/feed/category/dynamic)
    // Multi-select: videos whose duration is <= ANY selected threshold are blocked.
    // If empty, no duration filtering.
    // Default: only 10s pre-selected — wider defaults hid too much normal content.
    var blockedDurationSeconds: Set<Int> = [10]

    // Search-specific duration filter (min duration for search results)
    var searchMinDurationSeconds: Int? = nil

    // Category filtering（按 B 站分区 / 搜索结果 typename）
    var enableCategoryFilter: Bool = false
    var blockedCategories: Set<String> = []

    // Partition filtering（按 B 站一级/二级分区 tid 屏蔽，作用于首页推荐、热门、搜索流）
    // 默认开启并预置高频低质一级分区：动画/番剧/国创/游戏/美食/影视/娱乐/鬼畜。
    // 热门流本身就带 tid，因此这条规则是唯一不依赖补拉、开箱即生效的强过滤维度。
    var enablePartitionFilter: Bool = true
    var blockedTopZoneTids: Set<Int> = FilterSettings.defaultTopZones
    var blockedSubZoneTids: Set<Int> = []

    static let defaultTopZones: Set<Int> = [1, 13, 167, 4, 211, 181, 5, 119]

    // UP主 blacklist（按 mid）
    var enableUPBlockFilter: Bool = false
    var blockedUPMids: Set<Int> = []
    /// 黑名单 UP 主的名字，仅用于设置页展示，便于辨认与取消屏蔽。
    var blockedUPNames: [Int: String] = [:]

    // Creator type filtering（按博主内容类型批量屏蔽）
    // 基于视频分区 / tag / 标题 / copyright 自动识别 UP 主类型并缓存，
    // 用户可在设置里查看已识别的各类型博主、跳转主页、取消屏蔽。
    // 默认屏蔽数码评测、手机评测、游戏、美食、旅游、影视剪辑、二次元、
    // 日本动画、穿搭时尚、营销号、搬运号。
    var enableCreatorTypeFilter: Bool = true
    var blockedCreatorTypes: Set<CreatorType> = FilterSettings.defaultBlockedCreatorTypes
    /// 已识别博主画像缓存：mid -> profile。持久化，上限 800 个，超出按 lastSeen 淘汰。
    var knownCreators: [Int: CreatorProfile] = [:]
    /// 博主白名单：用户在看板里点「移除」的博主会进入白名单，
    /// classifyAndCache 不再对其重新分类，FilterEngine 也不再按类型屏蔽。
    /// 在白名单里再次点「删除」才会彻底移除。存储完整 profile 便于在设置页展示。
    var whitelistedCreators: [Int: CreatorProfile] = [:]

    /// 待用户确认的屏蔽清单：从某类型一键转入，尚未正式生效。
    /// 用户可逐个「确认生效」或一键「全部确认生效」后才会批量写入 blockedUPMids。
    /// 用于让用户在批量拉黑前再审阅一遍，避免把正常 UP 误拉黑。
    var confirmBlockedCreators: [Int: CreatorProfile] = [:]

    static let defaultBlockedCreatorTypes: Set<CreatorType> = [
        .techReview, .phoneReview, .gameStreamer, .foodBlogger,
        .travelBlogger, .filmEditor, .animeBlogger, .japaneseAnime,
        .fashionBlogger, .marketing, .repost
    ]

    // General keyword filtering（标题 + UP名 + 描述 + 分类/tag 联合匹配）
    // 默认开启：这是用户最主要依赖的过滤维度，且对「无 tag 视频」同样有效。
    var enableKeywordFilter: Bool = true
    var builtInKeywordsEnabled: Bool = true
    var customBlockedKeywords: [String] = []
    /// 被「关闭使用」的自定义关键词：保留在列表中（变灰），但不参与过滤。
    var disabledKeywords: Set<String> = []

    // Tag filtering（只匹配视频 tag 字段，比关键词更精准）
    // 默认开启：tag 是最可靠的内容类型信号，内置标签库只收录强指示 tag。
    var enableTagFilter: Bool = true
    var builtInTagsEnabled: Bool = true
    var customBlockedTags: [String] = []
    /// 被「关闭使用」的自定义标签：保留在列表中（变灰），但不参与过滤。
    var disabledTags: Set<String> = []

    // UI
    var showFilteredBanner: Bool = true

    /// Schema version used to migrate previously-persisted aggressive defaults.
    /// Optional so that settings saved by older builds (without this key) still decode.
    var schemaVersion: Int? = nil

    var stats: FilterStats = FilterStats()

    init() {}

    /// 逐字段 decodeIfPresent —— 老版本存储的设置 JSON 缺少后来新增的字段
    /// （如分区屏蔽、通用关键词、分类黑名单）时也能正常解码。
    /// 否则一次缺失字段就会让整份设置解码失败、被静默重置为默认值，
    /// 表现为"升级后过滤又不生效了"。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enableClickbaitFilter = try c.decodeIfPresent(Bool.self, forKey: .enableClickbaitFilter) ?? true
        enableExclamationFilter = try c.decodeIfPresent(Bool.self, forKey: .enableExclamationFilter) ?? false
        enableJapaneseTitleFilter = try c.decodeIfPresent(Bool.self, forKey: .enableJapaneseTitleFilter) ?? true
        enableJapaneseUPFilter = try c.decodeIfPresent(Bool.self, forKey: .enableJapaneseUPFilter) ?? true
        enableInsultWordFilter = try c.decodeIfPresent(Bool.self, forKey: .enableInsultWordFilter) ?? true
        builtInWordsEnabled = try c.decodeIfPresent(Bool.self, forKey: .builtInWordsEnabled) ?? true
        customBlockedWords = try c.decodeIfPresent([String].self, forKey: .customBlockedWords) ?? []
        disabledWords = try c.decodeIfPresent(Set<String>.self, forKey: .disabledWords) ?? []
        blockedDurationSeconds = try c.decodeIfPresent(Set<Int>.self, forKey: .blockedDurationSeconds) ?? [10]
        searchMinDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .searchMinDurationSeconds)
        enableCategoryFilter = try c.decodeIfPresent(Bool.self, forKey: .enableCategoryFilter) ?? false
        blockedCategories = try c.decodeIfPresent(Set<String>.self, forKey: .blockedCategories) ?? []
        enablePartitionFilter = try c.decodeIfPresent(Bool.self, forKey: .enablePartitionFilter) ?? true
        blockedTopZoneTids = try c.decodeIfPresent(Set<Int>.self, forKey: .blockedTopZoneTids) ?? FilterSettings.defaultTopZones
        blockedSubZoneTids = try c.decodeIfPresent(Set<Int>.self, forKey: .blockedSubZoneTids) ?? []
        enableUPBlockFilter = try c.decodeIfPresent(Bool.self, forKey: .enableUPBlockFilter) ?? false
        blockedUPMids = try c.decodeIfPresent(Set<Int>.self, forKey: .blockedUPMids) ?? []
        blockedUPNames = try c.decodeIfPresent([Int: String].self, forKey: .blockedUPNames) ?? [:]
        enableCreatorTypeFilter = try c.decodeIfPresent(Bool.self, forKey: .enableCreatorTypeFilter) ?? true
        blockedCreatorTypes = try c.decodeIfPresent(Set<CreatorType>.self, forKey: .blockedCreatorTypes) ?? FilterSettings.defaultBlockedCreatorTypes
        knownCreators = try c.decodeIfPresent([Int: CreatorProfile].self, forKey: .knownCreators) ?? [:]
        whitelistedCreators = try c.decodeIfPresent([Int: CreatorProfile].self, forKey: .whitelistedCreators) ?? [:]
        confirmBlockedCreators = try c.decodeIfPresent([Int: CreatorProfile].self, forKey: .confirmBlockedCreators) ?? [:]
        enableKeywordFilter = try c.decodeIfPresent(Bool.self, forKey: .enableKeywordFilter) ?? true
        builtInKeywordsEnabled = try c.decodeIfPresent(Bool.self, forKey: .builtInKeywordsEnabled) ?? true
        customBlockedKeywords = try c.decodeIfPresent([String].self, forKey: .customBlockedKeywords) ?? []
        disabledKeywords = try c.decodeIfPresent(Set<String>.self, forKey: .disabledKeywords) ?? []
        // 老版本没有这两个键：升级后默认开启 Tag 过滤，否则用户会以为"过滤又没效果"。
        enableTagFilter = try c.decodeIfPresent(Bool.self, forKey: .enableTagFilter) ?? true
        builtInTagsEnabled = try c.decodeIfPresent(Bool.self, forKey: .builtInTagsEnabled) ?? true
        customBlockedTags = try c.decodeIfPresent([String].self, forKey: .customBlockedTags) ?? []
        disabledTags = try c.decodeIfPresent(Set<String>.self, forKey: .disabledTags) ?? []
        showFilteredBanner = try c.decodeIfPresent(Bool.self, forKey: .showFilteredBanner) ?? true
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion)
        stats = try c.decodeIfPresent(FilterStats.self, forKey: .stats) ?? FilterStats()
    }

    /// Current filter-settings schema version.
    static let currentSchemaVersion = 7
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
        words.append(contentsOf: customBlockedWords.filter { !disabledWords.contains($0) })
        return words
    }

    /// 通用关键词：命中标题 / UP名 / 描述 / 分类 / tag 即拦截。
    /// 用于过滤日本动画、无厘头动画、影视信息、游戏信息、美食博主、游走游戏录播等。
    static let builtInKeywords: [String] = [
        "动画", "动漫", "日本动画", "二次元", "番剧", "新番", "MAD", "AMV",
        "游戏", "录播", "直播回放", "电竞", "手游", "单机", "通关", "攻略",
        "美食", "吃播", "探店", "做饭", "料理", "食谱", "吃货",
        "影视", "电影", "电视剧", "综艺", "影评", "解说电影", "追剧",
        "鬼畜", "吐槽", "Reaction", "反应视频", "挑战", "整蛊", "恶搞",
        "Vlog", "日常", "生活记录", "开箱", "测评", "试吃"
    ]

    /// 当前生效的通用关键词（内置 + 自定义），全部小写后返回便于不区分大小写匹配。
    var activeKeywords: [String] {
        var words: [String] = []
        if builtInKeywordsEnabled {
            words.append(contentsOf: FilterSettings.builtInKeywords)
        }
        words.append(contentsOf: customBlockedKeywords.filter { !disabledKeywords.contains($0) })
        return words.map { $0.lowercased() }.filter { !$0.isEmpty }
    }

    /// 内置标签库：只收录「内容类型强指示」的 tag，命中即说明该视频属于用户要屏蔽的
    /// 日本动画 / 无厘头动画 / 影视信息 / 游戏信息 / 美食 / 游戏录播 等类别。
    /// 刻意排除「挑战」「测评」「日常」这类过于泛化、会误伤的 tag。
    static let builtInTags: [String] = [
        // 一级内容类型（最短、最有效，覆盖「动画」「游戏」这类基础 tag）
        "动画", "动漫", "番剧", "游戏", "手游", "单机", "主机",
        "影视", "电影", "电视剧", "综艺", "美食", "鬼畜", "吃播", "录播",
        // 游戏（游戏信息 / 游戏录播）
        "游戏实况", "游戏解说", "实况解说", "单机游戏", "手机游戏", "网络游戏",
        "端游", "手游", "游戏攻略", "通关攻略", "游戏录播", "直播回放", "录播",
        "游戏杂谈", "电竞", "电子竞技", "主机游戏", "独立游戏", "游戏集锦",
        "游戏二创", "游戏直播", "手游实况", "游戏吐槽", "GMV",
        // 动画（日本动画 / 无厘头动画）
        "日本动画", "国产动画", "动画短片", "新番", "番剧", "追番", "动漫",
        "二次元", "MAD", "AMV", "MMD", "手书", "同人", "动漫杂谈", "动画解说",
        "泡面番", "番剧推荐", "动画杂谈", "特摄", "手办", "声优",
        // 影视 / 综艺
        "影视解说", "电影解说", "影视剪辑", "影视杂谈", "预告片", "电影混剪",
        "电视剧", "综艺", "追剧", "影评", "影视盘点", "影sir",
        // 美食
        "美食", "美食探店", "探店", "吃播", "美食制作", "美食测评", "家常菜",
        "料理", "做饭", "试吃", "下饭", "田园美食", "美食记录",
        // 鬼畜 / 整活
        "鬼畜", "鬼畜调教", "音MAD", "整活", "沙雕", "恶搞", "反应视频",
        "reaction", "整蛊"
    ]

    /// 当前生效的屏蔽标签（内置 + 自定义），小写后返回便于不区分大小写匹配。
    var activeTags: [String] {
        var words: [String] = []
        if builtInTagsEnabled {
            words.append(contentsOf: FilterSettings.builtInTags)
        }
        words.append(contentsOf: customBlockedTags.filter { !disabledTags.contains($0) })
        return words.map { $0.lowercased() }.filter { !$0.isEmpty }
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

// MARK: - Bilibili partition catalog（一级 / 二级分区）

/// A second-level Bilibili partition (二级分区).
struct BiliSubZone: Identifiable, Hashable {
    let tid: Int
    let name: String
    var id: Int { tid }
}

/// A top-level Bilibili partition (一级分区) together with its sub-zones.
struct BiliTopZone: Identifiable, Hashable {
    let tid: Int
    let name: String
    let subs: [BiliSubZone]
    var id: Int { tid }
}

/// Static catalog of Bilibili video partitions. Used by the partition filter to
/// map a video's leaf `tid` to its top-level zone, and to resolve display names.
enum BiliZone {

    static let all: [BiliTopZone] = [
        BiliTopZone(tid: 13, name: "番剧", subs: [
            BiliSubZone(tid: 33, name: "连载动画"),
            BiliSubZone(tid: 32, name: "完结动画"),
            BiliSubZone(tid: 51, name: "资讯"),
            BiliSubZone(tid: 152, name: "官方延伸"),
        ]),
        BiliTopZone(tid: 167, name: "国创", subs: [
            BiliSubZone(tid: 153, name: "国产动画"),
            BiliSubZone(tid: 168, name: "国产原创相关"),
            BiliSubZone(tid: 169, name: "布袋戏"),
            BiliSubZone(tid: 195, name: "动态漫·广播剧"),
            BiliSubZone(tid: 170, name: "资讯"),
        ]),
        BiliTopZone(tid: 65545, name: "放映厅", subs: []),
        BiliTopZone(tid: 177, name: "纪录片", subs: [
            BiliSubZone(tid: 37, name: "人文·历史"),
            BiliSubZone(tid: 178, name: "科学·探索·自然"),
            BiliSubZone(tid: 179, name: "军事"),
            BiliSubZone(tid: 180, name: "社会·美食·旅行"),
        ]),
        BiliTopZone(tid: 23, name: "电影", subs: [
            BiliSubZone(tid: 147, name: "华语电影"),
            BiliSubZone(tid: 145, name: "欧美电影"),
            BiliSubZone(tid: 146, name: "日本电影"),
            BiliSubZone(tid: 83, name: "其他国家"),
        ]),
        BiliTopZone(tid: 11, name: "电视剧", subs: [
            BiliSubZone(tid: 185, name: "国产剧"),
            BiliSubZone(tid: 187, name: "海外剧"),
        ]),
        BiliTopZone(tid: 1, name: "动画", subs: [
            BiliSubZone(tid: 24, name: "MAD·AMV"),
            BiliSubZone(tid: 25, name: "MMD·3D"),
            BiliSubZone(tid: 47, name: "同人·手书"),
            BiliSubZone(tid: 257, name: "配音"),
            BiliSubZone(tid: 210, name: "模玩·周边"),
            BiliSubZone(tid: 86, name: "特摄"),
            BiliSubZone(tid: 253, name: "动漫杂谈"),
            BiliSubZone(tid: 27, name: "综合"),
        ]),
        BiliTopZone(tid: 3, name: "音乐", subs: [
            BiliSubZone(tid: 28, name: "原创音乐"),
            BiliSubZone(tid: 29, name: "音乐现场"),
            BiliSubZone(tid: 31, name: "翻唱"),
            BiliSubZone(tid: 59, name: "演奏"),
            BiliSubZone(tid: 243, name: "乐评盘点"),
            BiliSubZone(tid: 30, name: "VOCALOID·UTAU"),
            BiliSubZone(tid: 193, name: "MV"),
            BiliSubZone(tid: 266, name: "音乐粉丝饭拍"),
            BiliSubZone(tid: 265, name: "AI音乐"),
            BiliSubZone(tid: 267, name: "电台"),
            BiliSubZone(tid: 244, name: "音乐教学"),
            BiliSubZone(tid: 130, name: "音乐综合"),
        ]),
        BiliTopZone(tid: 129, name: "舞蹈", subs: [
            BiliSubZone(tid: 20, name: "宅舞"),
            BiliSubZone(tid: 198, name: "街舞"),
            BiliSubZone(tid: 199, name: "明星舞蹈"),
            BiliSubZone(tid: 200, name: "国风舞蹈"),
            BiliSubZone(tid: 255, name: "颜值·网红舞"),
            BiliSubZone(tid: 154, name: "舞蹈综合"),
            BiliSubZone(tid: 156, name: "舞蹈教程"),
        ]),
        BiliTopZone(tid: 4, name: "游戏", subs: [
            BiliSubZone(tid: 17, name: "单机游戏"),
            BiliSubZone(tid: 171, name: "电子竞技"),
            BiliSubZone(tid: 172, name: "手机游戏"),
            BiliSubZone(tid: 65, name: "网络游戏"),
            BiliSubZone(tid: 173, name: "桌游棋牌"),
            BiliSubZone(tid: 121, name: "GMV"),
            BiliSubZone(tid: 136, name: "音游"),
            BiliSubZone(tid: 19, name: "Mugen"),
        ]),
        BiliTopZone(tid: 36, name: "知识", subs: [
            BiliSubZone(tid: 201, name: "科学科普"),
            BiliSubZone(tid: 124, name: "社科·法律·心理"),
            BiliSubZone(tid: 228, name: "人文历史"),
            BiliSubZone(tid: 207, name: "财经商业"),
            BiliSubZone(tid: 208, name: "校园学习"),
            BiliSubZone(tid: 209, name: "职业职场"),
            BiliSubZone(tid: 229, name: "设计·创意"),
            BiliSubZone(tid: 122, name: "野生技能协会"),
        ]),
        BiliTopZone(tid: 188, name: "科技", subs: [
            BiliSubZone(tid: 95, name: "数码"),
            BiliSubZone(tid: 230, name: "软件应用"),
            BiliSubZone(tid: 231, name: "计算机技术"),
            BiliSubZone(tid: 232, name: "科工机械"),
            BiliSubZone(tid: 233, name: "极客DIY"),
        ]),
        BiliTopZone(tid: 202, name: "资讯", subs: [
            BiliSubZone(tid: 203, name: "热点"),
            BiliSubZone(tid: 204, name: "环球"),
            BiliSubZone(tid: 205, name: "社会"),
            BiliSubZone(tid: 206, name: "综合"),
        ]),
        BiliTopZone(tid: 234, name: "运动", subs: [
            BiliSubZone(tid: 235, name: "篮球"),
            BiliSubZone(tid: 249, name: "足球"),
            BiliSubZone(tid: 164, name: "健身"),
            BiliSubZone(tid: 236, name: "竞技体育"),
            BiliSubZone(tid: 237, name: "运动文化"),
            BiliSubZone(tid: 238, name: "运动综合"),
        ]),
        BiliTopZone(tid: 223, name: "汽车", subs: [
            BiliSubZone(tid: 258, name: "汽车知识科普"),
            BiliSubZone(tid: 227, name: "购车攻略"),
            BiliSubZone(tid: 247, name: "新能源车"),
            BiliSubZone(tid: 245, name: "赛车"),
            BiliSubZone(tid: 246, name: "改装玩车"),
            BiliSubZone(tid: 240, name: "摩托车"),
            BiliSubZone(tid: 248, name: "房车"),
            BiliSubZone(tid: 176, name: "汽车生活"),
        ]),
        BiliTopZone(tid: 160, name: "生活", subs: [
            BiliSubZone(tid: 138, name: "搞笑"),
            BiliSubZone(tid: 254, name: "亲子"),
            BiliSubZone(tid: 250, name: "出行"),
            BiliSubZone(tid: 251, name: "三农"),
            BiliSubZone(tid: 239, name: "家居房产"),
            BiliSubZone(tid: 161, name: "手工"),
            BiliSubZone(tid: 162, name: "绘画"),
            BiliSubZone(tid: 21, name: "日常"),
        ]),
        BiliTopZone(tid: 211, name: "美食", subs: [
            BiliSubZone(tid: 76, name: "美食制作"),
            BiliSubZone(tid: 212, name: "美食侦探"),
            BiliSubZone(tid: 213, name: "美食测评"),
            BiliSubZone(tid: 214, name: "田园美食"),
            BiliSubZone(tid: 215, name: "美食记录"),
        ]),
        BiliTopZone(tid: 217, name: "动物圈", subs: [
            BiliSubZone(tid: 218, name: "喵星人"),
            BiliSubZone(tid: 219, name: "汪星人"),
            BiliSubZone(tid: 222, name: "小宠异宠"),
            BiliSubZone(tid: 221, name: "野生动物"),
            BiliSubZone(tid: 220, name: "动物二创"),
            BiliSubZone(tid: 75, name: "动物综合"),
        ]),
        BiliTopZone(tid: 65559, name: "VLOG", subs: []),
        BiliTopZone(tid: 119, name: "鬼畜", subs: [
            BiliSubZone(tid: 22, name: "鬼畜调教"),
            BiliSubZone(tid: 26, name: "音MAD"),
            BiliSubZone(tid: 126, name: "人力VOCALOID"),
            BiliSubZone(tid: 216, name: "鬼畜剧场"),
            BiliSubZone(tid: 127, name: "教程演示"),
        ]),
        BiliTopZone(tid: 155, name: "时尚", subs: [
            BiliSubZone(tid: 157, name: "美妆护肤"),
            BiliSubZone(tid: 252, name: "仿妆cos"),
            BiliSubZone(tid: 158, name: "穿搭"),
            BiliSubZone(tid: 159, name: "时尚潮流"),
        ]),
        BiliTopZone(tid: 5, name: "娱乐", subs: [
            BiliSubZone(tid: 241, name: "娱乐杂谈"),
            BiliSubZone(tid: 262, name: "CP安利"),
            BiliSubZone(tid: 263, name: "颜值安利"),
            BiliSubZone(tid: 242, name: "娱乐粉丝创作"),
            BiliSubZone(tid: 264, name: "娱乐资讯"),
            BiliSubZone(tid: 137, name: "明星综合"),
            BiliSubZone(tid: 71, name: "综艺"),
        ]),
        BiliTopZone(tid: 181, name: "影视", subs: [
            BiliSubZone(tid: 182, name: "影视杂谈"),
            BiliSubZone(tid: 183, name: "影视剪辑"),
            BiliSubZone(tid: 260, name: "影视整活"),
            BiliSubZone(tid: 259, name: "AI影像"),
            BiliSubZone(tid: 184, name: "预告·资讯"),
            BiliSubZone(tid: 85, name: "小剧场"),
            BiliSubZone(tid: 256, name: "短片"),
            BiliSubZone(tid: 261, name: "影视综合"),
        ]),
    ]

    private static let topByTid: [Int: BiliTopZone] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.tid, $0) })

    /// leaf tid -> top-level tid (a top-level tid maps to itself).
    private static let parentByLeaf: [Int: Int] = {
        var map: [Int: Int] = [:]
        for top in all {
            map[top.tid] = top.tid
            for sub in top.subs { map[sub.tid] = top.tid }
        }
        return map
    }()

    /// name -> tid, for both top-level and sub-level names (sub-level wins on collision).
    private static let tidByName: [String: Int] = {
        var map: [String: Int] = [:]
        // Sub-level names win over top-level names on collision.
        for top in all { map[top.name] = top.tid }
        for top in all {
            for sub in top.subs { map[sub.name] = sub.tid }
        }
        return map
    }()

    /// (name, tid) pairs sorted by name length descending, used for the
    /// substring fallback so the most specific name wins (「连载动画」 beats 「动画」).
    private static let namesByLength: [(name: String, tid: Int)] = {
        var pairs: [(String, Int)] = []
        for top in all {
            pairs.append((top.name, top.tid))
            for sub in top.subs { pairs.append((sub.name, sub.tid)) }
        }
        return pairs.sorted { $0.0.count > $1.0.count }
    }()

    private static let leafNameByTid: [Int: String] = {
        var map: [Int: String] = [:]
        for top in all { map[top.tid] = top.name }
        for top in all {
            for sub in top.subs { map[sub.tid] = sub.name }
        }
        return map
    }()

    /// 高频低质分区的一键屏蔽推荐（动画 / 番剧 / 国创 / 游戏 / 美食 / 影视 / 娱乐）。
    static let recommendedBlockTids: [Int] = [1, 13, 167, 4, 211, 181, 5]

    static func topZone(tid: Int) -> BiliTopZone? { topByTid[tid] }

    static func topTid(forLeaf tid: Int) -> Int? { parentByLeaf[tid] }

    static func topName(_ tid: Int) -> String? { topByTid[tid]?.name }

    static func leafName(_ tid: Int) -> String? { leafNameByTid[tid] }

    /// Reverse lookup: a leaf (or top) name to its tid, used as a fallback when a
    /// video carries a partition name but no `tid`. Exact match first; otherwise
    /// the longest known name contained in `name` wins (e.g. tname「手机游戏」→ 游戏).
    static func leafTid(forName name: String) -> Int? {
        if let tid = tidByName[name] { return tid }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        for pair in namesByLength where pair.name.count >= 2 {
            if trimmed.contains(pair.name) { return pair.tid }
        }
        return nil
    }
}

// MARK: - Creator type classification（博主类型识别）

/// 博主内容类型。基于视频的分区 tid / tag / 标题 / copyright 等信号
/// 对 UP 主进行归类，用于按「博主类型」批量屏蔽（如屏蔽所有数码评测博主）。
enum CreatorType: String, Codable, CaseIterable, Identifiable, Hashable {
    case techReview = "数码评测"
    case phoneReview = "手机评测"
    case gameStreamer = "游戏主播/UP"
    case foodBlogger = "美食博主"
    case travelBlogger = "旅游/出行博主"
    case knowledge = "知识/科普博主"
    case filmEditor = "影视/剪辑博主"
    case animeBlogger = "二次元博主"
    case japaneseAnime = "日本动画博主"
    case fashionBlogger = "穿搭/时尚博主"
    case autoReview = "汽车评测博主"
    case news = "新闻资讯号"
    case marketing = "营销号"
    case repost = "搬运号博主"
    case official = "官方账号"
    case enterprise = "企业号"
    case other = "其他"

    var id: String { rawValue }

    /// SF Symbol 图标，用于设置页展示。
    var icon: String {
        switch self {
        case .techReview: return "cpu"
        case .phoneReview: return "iphone"
        case .gameStreamer: return "gamecontroller"
        case .foodBlogger: return "fork.knife"
        case .travelBlogger: return "airplane"
        case .knowledge: return "books.vertical"
        case .filmEditor: return "film"
        case .animeBlogger: return "sparkles"
        case .japaneseAnime: return "character.book.closed"
        case .fashionBlogger: return "tshirt"
        case .autoReview: return "car"
        case .news: return "newspaper"
        case .marketing: return "megaphone"
        case .repost: return "arrow.triangle.2.circlepath"
        case .official: return "checkmark.seal.fill"
        case .enterprise: return "building.2"
        case .other: return "person"
        }
    }

    /// 主题色，用于设置页 chip 着色。
    var color: Color {
        switch self {
        case .techReview: return .blue
        case .phoneReview: return .indigo
        case .gameStreamer: return .purple
        case .foodBlogger: return .orange
        case .travelBlogger: return .teal
        case .knowledge: return .brown
        case .filmEditor: return .pink
        case .animeBlogger: return .purple
        case .japaneseAnime: return .red
        case .fashionBlogger: return .pink
        case .autoReview: return .mint
        case .news: return .gray
        case .marketing: return .red
        case .repost: return .red
        case .official: return .green
        case .enterprise: return .green
        case .other: return .gray
        }
    }
}

/// 已识别博主的画像，按 mid 缓存。持久化在 FilterSettings 里。
struct CreatorProfile: Codable, Hashable, Identifiable {
    var id: Int { mid }
    let mid: Int
    var name: String
    var avatar: String
    var type: CreatorType
    /// 识别置信度 0~1，多次采样后类型稳定则升高。
    var confidence: Double
    var firstSeen: Date
    var lastSeen: Date
    /// 已参与分类的视频样本数。
    var sampleCount: Int
    /// 用户手动指定过类型（「移入其他分类」）。为 true 时分类器不再自动改写类型。
    /// 用可选类型保证老版本持久化数据（无该字段）仍能正常解码。
    var isManualType: Bool? = nil

    /// 是否由用户手动锁定了分类。
    var manuallyTyped: Bool { isManualType == true }

    init(mid: Int, name: String, avatar: String = "", type: CreatorType, confidence: Double = 0) {
        self.mid = mid
        self.name = name
        self.avatar = avatar
        self.type = type
        self.confidence = confidence
        self.firstSeen = Date()
        self.lastSeen = Date()
        self.sampleCount = 1
    }
}

// MARK: - CreatorClassifier

/// 基于单条视频的可见信号（tid / tags / title / copyright / 互动数据）
/// 推断 UP 主的内容类型。不依赖额外网络请求，过滤前即可运行。
///
/// 分类优先级：官方/企业号（用户名模式） > 分区 tid > 标签 tag > 标题关键词 > copyright。
/// 首页推荐流只有 title+upName，分类会落到 .other 或靠标题关键词命中；
/// 热门/搜索流带 tid+tag，分类较准确；补拉 copyright 后可识别搬运号。
enum CreatorClassifier {

    /// 用户名里出现这些词，基本可以判定为官方/企业账号。
    private static let officialNameHints = [
        "官方", "Official", "旗舰店", "公众号", "频道", "工作室", "传媒",
        "文化", "科技", "公司", "集团", "品牌", "认证", "bilibili", "哔哩哔哩"
    ]
    /// 企业号名称后缀（更偏机构）。
    private static let enterpriseNameHints = [
        "公司", "集团", "传媒", "文化", "科技", "品牌", "官方账号"
    ]

    /// 手机相关关键词，命中数码分区时进一步细分为「手机评测」。
    private static let phoneKeywords = [
        "iphone", "小米", "华为", "oppo", "vivo", "荣耀", "三星", "一加",
        "手机", "续航", "拍照", "骁龙", "天玑", "芯片", "处理器", "旗舰机",
        "redmi", "realme", "iqoo", "魅族", "努比亚", "折叠屏"
    ]

    /// 各博主类型对应的分区 tid（一级分区与叶子分区混排，命中即归类）。
    /// 顺序不参与判定，tid 之间互不重叠。
    private static let zoneTidMap: [CreatorType: Set<Int>] = [
        .gameStreamer: [4, 17, 171, 172, 65, 173, 121, 136, 19],
        .foodBlogger: [211, 212, 76],
        .travelBlogger: [250, 259],
        .filmEditor: [181, 182, 183, 85, 184],
        .knowledge: [36, 201, 122, 124, 207, 208, 209, 228, 229],
        .animeBlogger: [1, 24, 25, 47, 119, 253, 27, 86, 257, 210, 13, 167],
        .fashionBlogger: [155, 157, 158],
        .autoReview: [223, 227, 247, 258, 176, 245, 246, 248, 240],
        .news: [202, 203, 204, 205, 206],
        .techReview: [188, 95, 230, 231, 232, 233],
    ]

    /// 无 tid 时用于 tag / 标题兜底的关键词表，顺序即优先级。
    private static let keywordRules: [(CreatorType, [String])] = [
        (.gameStreamer, ["游戏", "手游", "单机", "攻略", "实况", "直播切片", "电竞"]),
        (.foodBlogger, ["美食", "探店", "菜谱", "做法", "吃播", "厨艺"]),
        (.travelBlogger, ["旅游", "vlog", "自驾", "出行", "城市漫步"]),
        (.filmEditor, ["影视", "电影", "解说", "盘点", "混剪", "剪辑"]),
        (.knowledge, ["科普", "知识", "历史", "财经", "社科", "人文"]),
        (.animeBlogger, ["动画", "动漫", "番剧", "二次元", "鬼畜", "mad"]),
        (.fashionBlogger, ["穿搭", "ootd", "美妆", "护肤", "时尚"]),
        (.autoReview, ["汽车", "试驾", "提车", "新能源", "买车", "车型"]),
        (.news, ["新闻", "热点", "资讯", "时政", "突发", "通报"]),
        (.techReview, ["数码", "评测", "开箱", "硬件"]),
    ]

    /// 分区 tid -> 博主类型。叶子分区和一级分区都走这里。
    private static func typeForZone(_ tid: Int) -> CreatorType? {
        for (type, tids) in zoneTidMap where tids.contains(tid) {
            return type
        }
        return nil
    }

    /// 数码类命中机型关键词时细分为「手机评测」。
    private static func refine(_ type: CreatorType, haystack: String) -> CreatorType {
        if type == .techReview, phoneKeywords.contains(where: { haystack.contains($0) }) {
            return .phoneReview
        }
        return type
    }

    private static func keywordMatch(in text: String) -> CreatorType? {
        for (type, words) in keywordRules where words.contains(where: { text.contains($0) }) {
            return type
        }
        return nil
    }

    /// 推断单条视频所属的博主类型。
    static func classify(video: Video) -> CreatorType {
        let name = video.upName
        let haystack = (video.title + " " + video.tags.joined(separator: " ")).lowercased()

        // 1. 官方/企业号（用户名模式，优先级最高）
        let lowerName = name.lowercased()
        for hint in enterpriseNameHints where lowerName.contains(hint.lowercased()) {
            return .enterprise
        }
        for hint in officialNameHints where lowerName.contains(hint.lowercased()) {
            return .official
        }

        // 2. 搬运号：copyright=2（转载）且无明显原创加工信号
        if video.copyright == 2 {
            // 有解说/混剪等原创加工信号时不判为搬运号
            let originalSignals = ["解说", "吐槽", "盘点", "混剪", "reaction", "反应", "配音", "鬼畜"]
            let hasOriginal = originalSignals.contains { haystack.contains($0.lowercased()) }
            if !hasOriginal {
                return .repost
            }
        }

        // 3. 营销号：低投币比 + 低收藏比 + （标题党或转载）
        //    单条视频难以稳定判断，这里用「转载 + 极低互动」作为弱信号，
        //    多次采样后 AppStore 会把它固化为 marketing 类型。
        if video.copyright == 2, video.views > 1000 {
            let coinRate = video.views > 0 ? Double(video.coins) / Double(video.views) : 0
            let favRate = video.views > 0 ? Double(video.favorites) / Double(video.views) : 0
            if coinRate < 0.001 && favRate < 0.002 {
                return .marketing
            }
        }

        let leafTid = video.tid

        // 4. 叶子/二级分区 tid（最具体，优先命中）
        if leafTid != 0, let type = typeForZone(leafTid) {
            return refine(type, haystack: haystack)
        }

        // 5. 一级分区 tid（叶子分区表里没有时按 B 站分区树回退）
        if let topTid = BiliZone.topTid(forLeaf: leafTid), let type = typeForZone(topTid) {
            return refine(type, haystack: haystack)
        }

        // 6. tag 关键词
        if !video.tags.isEmpty,
           let type = keywordMatch(in: video.tags.joined(separator: " ").lowercased()) {
            return refine(type, haystack: haystack)
        }

        // 7. 纯标题关键词兜底（首页推荐流无 tid/tag 时唯一可用信号）
        if let type = keywordMatch(in: haystack) {
            return refine(type, haystack: haystack)
        }

        return .other
    }
}
