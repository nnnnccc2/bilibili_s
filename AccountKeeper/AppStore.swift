//
//  AppStore.swift
//  BiliBili
//
//  Central store: filter settings, user, watch history, and purification stats
//

import Foundation

final class AppStore: ObservableObject {
    // MARK: - Published state

    @Published var settings: FilterSettings {
        didSet { saveSettings() }
    }
    @Published var currentUser: User?
    @Published var history: [HistoryItem] = []
    @Published var lastBlockedCount: Int = 0

    /// 首页数据诊断：本次拉取到的视频总数 / 已带回 tag 的条数 / 已带回分区 tid 的条数。
    /// 用来在设备上直接确认「元数据补拉」是否真的成功（tag 全 0 = 补拉失败）。
    struct FeedDiagnostics {
        var total: Int = 0
        var withTags: Int = 0
        var withTid: Int = 0
        /// 补拉结果摘要（含失败错误码），用于定位为什么 tag 是 0
        var note: String = ""
    }
    @Published var feedDiagnostics = FeedDiagnostics()
    /// 本次拉取中被 Tag 规则拦下的条数（用于确认 Tag 过滤是否命中）。
    @Published var lastTagBlockedCount: Int = 0

    /// Number of immersive full-screen overlays currently presented
    /// (video player, UP空间, 设置, 搜索...). When > 0 the bottom tab bar hides
    /// so the overlay covers the whole screen. Uses a counter because overlays
    /// can be stacked (e.g. 视频 → UP空间).
    @Published var immersiveDepth: Int = 0

    func pushImmersive() { immersiveDepth += 1 }
    func popImmersive() { immersiveDepth = max(0, immersiveDepth - 1) }

    // MARK: - Persistence keys

    private let settingsKey = "BiliBili.filterSettings"
    private let userKey = "BiliBili.currentUser"
    private let historyKey = "BiliBili.watchHistory"
    /// 待执行的设置写盘任务（用于合并短时间内的密集改动）。
    private var pendingSave: DispatchWorkItem?

    init() {
        self.settings = FilterSettings()
        loadSettings()
        loadUser()
        loadHistory()
    }

    // MARK: - Filter engine (rebuilt whenever settings change)

    var engine: FilterEngine { FilterEngine(settings: settings) }

    /// Applies the global filter to a list of videos, returning only those that pass.
    /// - Parameter countStats: when false (re-filtering after settings change), the
    ///   per-reason counters are not incremented again.
    func applyFilter(_ videos: [Video], countStats: Bool = true) -> [Video] {
        classifyAndCache(videos)
        let engine = self.engine
        var passed: [Video] = []
        var blocked = 0
        for v in videos {
            if let reason = engine.shouldBlock(v) {
                blocked += 1
                if countStats { settings.stats.add(reason) }
            } else {
                passed.append(v)
            }
        }
        if blocked > 0 {
            lastBlockedCount = blocked
        }
        return passed
    }

    /// Applies the search-specific filter (global rules + min-duration).
    /// - Parameter applyMinDuration: false for user search — user results have no
    ///   duration and must not be filtered out by a min-duration threshold.
    func applySearchFilter(_ videos: [Video], countStats: Bool = true, applyMinDuration: Bool = true) -> [Video] {
        classifyAndCache(videos)
        let engine = self.engine
        var passed: [Video] = []
        var blocked = 0
        for v in videos {
            if let reason = engine.shouldBlockInSearch(v, applyMinDuration: applyMinDuration) {
                blocked += 1
                if countStats { settings.stats.add(reason) }
            } else {
                passed.append(v)
            }
        }
        if blocked > 0 {
            lastBlockedCount = blocked
        }
        return passed
    }

    // MARK: - Creator classification cache

    /// 对一批视频的 UP 主进行类型识别并写入 knownCreators 缓存。
    /// 多次采样后类型稳定则置信度升高，类型漂移则降低并可能切换类型。
    /// 缓存上限 800，超出按 lastSeen 淘汰最旧博主。
    func classifyAndCache(_ videos: [Video]) {
        let now = Date()
        let whitelist = settings.whitelistedCreators
        // 先在本地副本上合并，循环结束后一次性写回 settings。
        // 之前每条视频都写一次 settings（触发 didSet → 整份设置同步 JSON 编码），
        // 是首页/热门/搜索列表卡顿的主要来源。
        var cache = settings.knownCreators
        for v in videos {
            guard v.upMid != 0 else { continue }
            // 白名单博主不再重新分类，避免用户移除后又被自动加回屏蔽列表。
            guard whitelist[v.upMid] == nil else { continue }
            let detected = CreatorClassifier.classify(video: v)
            if var existing = cache[v.upMid] {
                existing.sampleCount += 1
                existing.lastSeen = now
                if !v.upName.isEmpty { existing.name = v.upName }
                if !v.upAvatar.isEmpty { existing.avatar = v.upAvatar }
                if existing.manuallyTyped {
                    // 用户手动指定过分类：只更新统计信息，不再自动改写类型。
                } else if existing.type == detected {
                    existing.confidence = min(1.0, existing.confidence + 0.15)
                } else {
                    existing.confidence -= 0.25
                    if existing.confidence <= 0 {
                        existing.type = detected
                        existing.confidence = detected == .other ? 0.1 : 0.4
                    }
                }
                cache[v.upMid] = existing
            } else {
                let profile = CreatorProfile(
                    mid: v.upMid,
                    name: v.upName,
                    avatar: v.upAvatar,
                    type: detected,
                    confidence: detected == .other ? 0.1 : 0.5
                )
                cache[v.upMid] = profile
            }
        }
        // 缓存淘汰：超过 800 时按 lastSeen 降序保留前 800
        if cache.count > 800 {
            let keep = cache.values
                .sorted { $0.lastSeen > $1.lastSeen }
                .prefix(800)
            cache = Dictionary(uniqueKeysWithValues: keep.map { ($0.mid, $0) })
        }
        if cache != settings.knownCreators {
            settings.knownCreators = cache
        }
    }

    // MARK: - 一键最强净化

    /// 把当前生效的所有过滤维度一次性打开，并预置高频低质分区。
    /// 用于「设置里看起来都开了、实际一条都没被拦」的场景：
    /// 分区/分类开关和内置词库默认是关的，只开总开关不会命中任何内容。
    func enableStrongPurification() {
        settings.enableKeywordFilter = true
        settings.builtInKeywordsEnabled = true
        settings.enableTagFilter = true
        settings.builtInTagsEnabled = true
        settings.enablePartitionFilter = true
        settings.enableClickbaitFilter = true
        settings.enableInsultWordFilter = true
        settings.enableCreatorTypeFilter = true
        settings.blockedCreatorTypes = FilterSettings.defaultBlockedCreatorTypes
        // 动画 / 番剧 / 国创 / 游戏 / 美食 / 影视 / 娱乐 / 鬼畜
        settings.blockedTopZoneTids.formUnion([1, 13, 167, 4, 211, 181, 5, 119])
    }

    /// 当前真正生效的过滤维度摘要，显示在首页诊断行，便于确认开关状态。
    var activeFilterSummary: String {
        let s = settings
        var on: [String] = []
        if s.enableKeywordFilter { on.append(s.builtInKeywordsEnabled ? "关键词+词库" : "关键词") }
        if s.enableTagFilter { on.append(s.builtInTagsEnabled ? "tag+词库" : "tag") }
        if s.enablePartitionFilter { on.append("分区\(s.blockedTopZoneTids.count)") }
        if s.enableCreatorTypeFilter { on.append("博主类型\(s.blockedCreatorTypes.count)") }
        if s.enableCategoryFilter { on.append("分类") }
        if s.enableClickbaitFilter { on.append("标题党") }
        if s.enableInsultWordFilter { on.append("贬低词") }
        if s.enableJapaneseTitleFilter { on.append("日文标题") }
        if s.enableJapaneseUPFilter { on.append("日文UP") }
        return on.isEmpty ? "未开启任何过滤" : "已开 " + on.joined(separator: "/")
    }

    // MARK: - Settings persistence

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(FilterSettings.self, from: data) {
            self.settings = decoded
            migrateSettingsIfNeeded()
        }
    }

    /// Older builds defaulted the global duration block to 10s/28s/30s, which
    /// hid a large part of the normal feed. Migrate persisted settings to the
    /// lighter default once, then stamp the current schema version.
    private func migrateSettingsIfNeeded() {
        guard (settings.schemaVersion ?? 0) < FilterSettings.currentSchemaVersion else { return }
        if settings.blockedDurationSeconds == [10, 28, 30] {
            settings.blockedDurationSeconds = [10]
        }
        // v6：老版本把分区屏蔽和内置词库默认设为关闭，导致「总开关开着却一条都拦不住」。
        // 这里一次性打开各维度并预置高频低质分区，之后用户手动关闭仍会生效。
        if (settings.schemaVersion ?? 0) < 6 {
            settings.enableKeywordFilter = true
            settings.builtInKeywordsEnabled = true
            settings.enableTagFilter = true
            settings.builtInTagsEnabled = true
            settings.enablePartitionFilter = true
            settings.blockedTopZoneTids.formUnion(FilterSettings.defaultTopZones)
        }
        // v7：新增「博主类型过滤」维度，老用户升级后默认开启并预置屏蔽类型。
        if (settings.schemaVersion ?? 0) < 7 {
            settings.enableCreatorTypeFilter = true
            settings.blockedCreatorTypes = FilterSettings.defaultBlockedCreatorTypes
        }
        settings.schemaVersion = FilterSettings.currentSchemaVersion
    }

    private func saveSettings() {
        // 合并短时间内的多次改动，并在后台线程编码。
        // 原来每次点击（包括每条视频的分类缓存写入）都会在主线程同步编码整份设置，
        // 数百位博主缓存时点击「删除」会有明显延迟。
        pendingSave?.cancel()
        let snapshot = settings
        let key = settingsKey
        let item = DispatchWorkItem {
            if let encoded = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
        pendingSave = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    /// 立即落盘。App 进入后台时调用，避免防抖窗口内的最后改动丢失。
    func flushSettings() {
        pendingSave?.cancel()
        pendingSave = nil
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    // MARK: - Word management

    func addCustomWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !settings.customBlockedWords.contains(trimmed) else {
            // 已存在但处于停用状态时，添加即视为重新启用
            settings.disabledWords.remove(trimmed)
            return
        }
        settings.customBlockedWords.append(trimmed)
    }

    func removeCustomWord(_ word: String) {
        settings.customBlockedWords.removeAll { $0 == word }
        settings.disabledWords.remove(word)
    }

    /// 关闭/恢复某条自定义屏蔽词。关闭后条目保留并变灰，但不参与过滤。
    func toggleCustomWord(_ word: String) {
        if settings.disabledWords.contains(word) {
            settings.disabledWords.remove(word)
        } else {
            settings.disabledWords.insert(word)
        }
    }

    // MARK: - UP主 blacklist

    func blockUP(mid: Int, name: String = "") {
        guard mid != 0 else { return }
        settings.blockedUPMids.insert(mid)
        if !name.isEmpty { settings.blockedUPNames[mid] = name }
    }

    func unblockUP(mid: Int) {
        settings.blockedUPMids.remove(mid)
        settings.blockedUPNames.removeValue(forKey: mid)
    }

    // MARK: - Creator type filter management

    func blockCreatorType(_ type: CreatorType) {
        settings.blockedCreatorTypes.insert(type)
    }

    func unblockCreatorType(_ type: CreatorType) {
        settings.blockedCreatorTypes.remove(type)
    }

    func toggleCreatorType(_ type: CreatorType) {
        if settings.blockedCreatorTypes.contains(type) {
            unblockCreatorType(type)
        } else {
            blockCreatorType(type)
        }
    }

    /// 恢复默认屏蔽的博主类型集合。
    func resetBlockedCreatorTypes() {
        settings.blockedCreatorTypes = FilterSettings.defaultBlockedCreatorTypes
    }

    /// 把博主移入白名单：从 knownCreators 移除并加入 whitelistedCreators。
    /// 白名单内的博主不会被 classifyAndCache 重新分类，也不会被博主类型规则屏蔽。
    /// 误判博主用此方法「移除」后即永久放行，直到用户在白名单里再次删除。
    func removeCreator(mid: Int) {
        if let profile = settings.knownCreators[mid] {
            settings.whitelistedCreators[mid] = profile
        }
        settings.knownCreators.removeValue(forKey: mid)
    }

    /// 把归错类的博主手动移入其他分类。手动类型会锁定，分类器不再自动改写。
    func moveCreator(mid: Int, to type: CreatorType) {
        guard var profile = settings.knownCreators[mid] ?? settings.whitelistedCreators[mid] else { return }
        profile.type = type
        profile.confidence = 1.0
        profile.isManualType = true
        settings.knownCreators[mid] = profile
        // 手动改类后不再属于「放行」名单，重新参与分类屏蔽判断。
        settings.whitelistedCreators.removeValue(forKey: mid)
    }

    /// 把博主永久加入黑名单：按 mid 拦截其所有视频，并从识别缓存 / 白名单中移除。
    func blockCreatorPermanently(mid: Int, name: String = "") {
        guard mid != 0 else { return }
        settings.blockedUPMids.insert(mid)
        let displayName = name.isEmpty
            ? (settings.knownCreators[mid]?.name ?? settings.whitelistedCreators[mid]?.name ?? "")
            : name
        if !displayName.isEmpty { settings.blockedUPNames[mid] = displayName }
        settings.enableUPBlockFilter = true
        settings.knownCreators.removeValue(forKey: mid)
        settings.whitelistedCreators.removeValue(forKey: mid)
    }

    /// 把博主从白名单彻底移除（删除）。
    /// 移除后该博主下次出现在视频流中时会被重新分类，可能再次进入屏蔽列表。
    func removeFromWhitelist(mid: Int) {
        settings.whitelistedCreators.removeValue(forKey: mid)
    }

    /// 清空博主白名单。
    func clearCreatorWhitelist() {
        settings.whitelistedCreators.removeAll()
    }

    /// 清空已识别博主缓存。
    func clearKnownCreators() {
        settings.knownCreators.removeAll()
    }

    // MARK: - Category blacklist

    func blockCategory(_ category: String) {
        let trimmed = category.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        settings.blockedCategories.insert(trimmed)
    }

    func unblockCategory(_ category: String) {
        settings.blockedCategories.remove(category)
    }

    // MARK: - Partition blacklist（一级 / 二级分区 tid）

    func blockTopZone(tid: Int) {
        guard tid != 0 else { return }
        settings.blockedTopZoneTids.insert(tid)
        // 勾选一级分区时同步勾选其下所有已知二级分区，保证仅在二级层面返回的
        // 视频（如搜索流只给叶子 tid）也能被拦截。
        if let zone = BiliZone.topZone(tid: tid) {
            for sub in zone.subs { settings.blockedSubZoneTids.insert(sub.tid) }
        }
    }

    func unblockTopZone(tid: Int) {
        settings.blockedTopZoneTids.remove(tid)
        if let zone = BiliZone.topZone(tid: tid) {
            for sub in zone.subs { settings.blockedSubZoneTids.remove(sub.tid) }
        }
    }

    func toggleTopZone(tid: Int) {
        if settings.blockedTopZoneTids.contains(tid) {
            unblockTopZone(tid: tid)
        } else {
            blockTopZone(tid: tid)
        }
    }

    func blockSubZone(tid: Int) {
        guard tid != 0 else { return }
        settings.blockedSubZoneTids.insert(tid)
        // 若该二级分区的所有兄弟分区都被勾选，则自动勾选其一级分区。
        if let topTid = BiliZone.topTid(forLeaf: tid),
           topTid != tid,
           let zone = BiliZone.topZone(tid: topTid),
           !zone.subs.isEmpty,
           zone.subs.allSatisfy({ settings.blockedSubZoneTids.contains($0.tid) }) {
            settings.blockedTopZoneTids.insert(topTid)
        }
    }

    func unblockSubZone(tid: Int) {
        settings.blockedSubZoneTids.remove(tid)
        if let topTid = BiliZone.topTid(forLeaf: tid), topTid != tid {
            settings.blockedTopZoneTids.remove(topTid)
        }
    }

    func toggleSubZone(tid: Int) {
        if settings.blockedSubZoneTids.contains(tid) {
            unblockSubZone(tid: tid)
        } else {
            blockSubZone(tid: tid)
        }
    }

    func clearPartitionBlocklist() {
        settings.blockedTopZoneTids.removeAll()
        settings.blockedSubZoneTids.removeAll()
    }

    /// 一键屏蔽高频低质分区（动画 / 番剧 / 国创 / 游戏 / 美食 / 影视 / 娱乐）。
    func blockRecommendedZones() {
        for tid in BiliZone.recommendedBlockTids {
            blockTopZone(tid: tid)
        }
    }

    // MARK: - General keyword blacklist

    func addBlockedKeyword(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !settings.customBlockedKeywords.contains(trimmed) else {
            settings.disabledKeywords.remove(trimmed)
            return
        }
        settings.customBlockedKeywords.append(trimmed)
    }

    func removeBlockedKeyword(_ word: String) {
        settings.customBlockedKeywords.removeAll { $0 == word }
        settings.disabledKeywords.remove(word)
    }

    /// 关闭/恢复某条自定义关键词。关闭后条目保留并变灰，但不参与过滤。
    func toggleBlockedKeyword(_ word: String) {
        if settings.disabledKeywords.contains(word) {
            settings.disabledKeywords.remove(word)
        } else {
            settings.disabledKeywords.insert(word)
        }
    }

    // MARK: - Tag blacklist

    func addBlockedTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !settings.customBlockedTags.contains(trimmed) else {
            settings.disabledTags.remove(trimmed)
            return
        }
        settings.customBlockedTags.append(trimmed)
    }

    func removeBlockedTag(_ tag: String) {
        settings.customBlockedTags.removeAll { $0 == tag }
        settings.disabledTags.remove(tag)
    }

    /// 关闭/恢复某条自定义标签。关闭后条目保留并变灰，但不参与过滤。
    func toggleBlockedTag(_ tag: String) {
        if settings.disabledTags.contains(tag) {
            settings.disabledTags.remove(tag)
        } else {
            settings.disabledTags.insert(tag)
        }
    }

    // MARK: - User / login

    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let decoded = try? JSONDecoder().decode(User.self, from: data) {
            self.currentUser = decoded
        }
    }

    /// Called after QR code login succeeds (cookies already stored in BiliAPI).
    /// Fetches the logged-in user's profile and persists it.
    func loginAfterQRSuccess(completion: @escaping (Bool) -> Void) {
        BiliAPI.shared.fetchUserInfo { [weak self] user in
            DispatchQueue.main.async {
                guard let self = self, let user = user else {
                    completion(false)
                    return
                }
                self.currentUser = user
                if let encoded = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(encoded, forKey: self.userKey)
                }
                completion(true)
            }
        }
    }

    func logout() {
        currentUser = nil
        BiliAPI.shared.clearCookies()
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    // MARK: - Watch history

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            self.history = decoded
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }

    /// Called when a video starts playing. Creates or updates a history entry.
    func addHistory(_ video: Video) {
        if let existingIndex = history.firstIndex(where: { $0.videoId == video.id }) {
            var item = history.remove(at: existingIndex)
            item.watchedAt = Date()
            history.insert(item, at: 0)
        } else {
            let item = HistoryItem(
                videoId: video.id,
                title: video.title,
                cover: video.cover,
                upName: video.upName,
                duration: video.duration,
                progress: 0
            )
            history.insert(item, at: 0)
        }
        // Keep last 50
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        saveHistory()
    }

    func updateProgress(videoId: String, progress: Int) {
        if let index = history.firstIndex(where: { $0.videoId == videoId }) {
            history[index].progress = progress
            saveHistory()
        }
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
}
