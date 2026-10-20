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
    var byTag: Int = 0
    var byPartition: Int = 0

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
    var enablePartitionFilter: Bool = false
    var blockedTopZoneTids: Set<Int> = []
    var blockedSubZoneTids: Set<Int> = []

    // UP主 blacklist（按 mid）
    var enableUPBlockFilter: Bool = false
    var blockedUPMids: Set<Int> = []

    // General keyword filtering（标题 + UP名 + 描述 + 分类/tag 联合匹配）
    var enableKeywordFilter: Bool = false
    var builtInKeywordsEnabled: Bool = false
    var customBlockedKeywords: [String] = []

    // Tag filtering（只匹配视频 tag 字段，比关键词更精准）
    // 默认开启：tag 是最可靠的内容类型信号，内置标签库只收录强指示 tag。
    var enableTagFilter: Bool = true
    var builtInTagsEnabled: Bool = true
    var customBlockedTags: [String] = []

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
        blockedDurationSeconds = try c.decodeIfPresent(Set<Int>.self, forKey: .blockedDurationSeconds) ?? [10]
        searchMinDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .searchMinDurationSeconds)
        enableCategoryFilter = try c.decodeIfPresent(Bool.self, forKey: .enableCategoryFilter) ?? false
        blockedCategories = try c.decodeIfPresent(Set<String>.self, forKey: .blockedCategories) ?? []
        enablePartitionFilter = try c.decodeIfPresent(Bool.self, forKey: .enablePartitionFilter) ?? false
        blockedTopZoneTids = try c.decodeIfPresent(Set<Int>.self, forKey: .blockedTopZoneTids) ?? []
        blockedSubZoneTids = try c.decodeIfPresent(Set<Int>.self, forKey: .blockedSubZoneTids) ?? []
        enableUPBlockFilter = try c.decodeIfPresent(Bool.self, forKey: .enableUPBlockFilter) ?? false
        blockedUPMids = try c.decodeIfPresent(Set<Int>.self, forKey: .blockedUPMids) ?? []
        enableKeywordFilter = try c.decodeIfPresent(Bool.self, forKey: .enableKeywordFilter) ?? false
        builtInKeywordsEnabled = try c.decodeIfPresent(Bool.self, forKey: .builtInKeywordsEnabled) ?? false
        customBlockedKeywords = try c.decodeIfPresent([String].self, forKey: .customBlockedKeywords) ?? []
        // 老版本没有这两个键：升级后默认开启 Tag 过滤，否则用户会以为"过滤又没效果"。
        enableTagFilter = try c.decodeIfPresent(Bool.self, forKey: .enableTagFilter) ?? true
        builtInTagsEnabled = try c.decodeIfPresent(Bool.self, forKey: .builtInTagsEnabled) ?? true
        customBlockedTags = try c.decodeIfPresent([String].self, forKey: .customBlockedTags) ?? []
        showFilteredBanner = try c.decodeIfPresent(Bool.self, forKey: .showFilteredBanner) ?? true
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion)
        stats = try c.decodeIfPresent(FilterStats.self, forKey: .stats) ?? FilterStats()
    }

    /// Current filter-settings schema version.
    static let currentSchemaVersion = 5
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
        words.append(contentsOf: customBlockedKeywords)
        return words.map { $0.lowercased() }.filter { !$0.isEmpty }
    }

    /// 内置标签库：只收录「内容类型强指示」的 tag，命中即说明该视频属于用户要屏蔽的
    /// 日本动画 / 无厘头动画 / 影视信息 / 游戏信息 / 美食 / 游戏录播 等类别。
    /// 刻意排除「挑战」「测评」「日常」这类过于泛化、会误伤的 tag。
    static let builtInTags: [String] = [
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
        words.append(contentsOf: customBlockedTags)
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
