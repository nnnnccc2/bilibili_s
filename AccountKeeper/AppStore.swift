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
        settings.schemaVersion = FilterSettings.currentSchemaVersion
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    // MARK: - Word management

    func addCustomWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !settings.customBlockedWords.contains(trimmed) else { return }
        settings.customBlockedWords.append(trimmed)
    }

    func removeCustomWord(_ word: String) {
        settings.customBlockedWords.removeAll { $0 == word }
    }

    // MARK: - UP主 blacklist

    func blockUP(mid: Int, name: String = "") {
        guard mid != 0 else { return }
        settings.blockedUPMids.insert(mid)
    }

    func unblockUP(mid: Int) {
        settings.blockedUPMids.remove(mid)
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
        guard !settings.customBlockedKeywords.contains(trimmed) else { return }
        settings.customBlockedKeywords.append(trimmed)
    }

    func removeBlockedKeyword(_ word: String) {
        settings.customBlockedKeywords.removeAll { $0 == word }
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
