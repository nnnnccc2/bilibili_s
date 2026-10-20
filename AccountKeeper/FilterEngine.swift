//
//  FilterEngine.swift
//  BiliBili
//
//  Core filtering logic for blocking spam / low-quality videos
//

import Foundation

/// Evaluates videos against the active filter settings and returns a block reason
/// when a video should be hidden.
final class FilterEngine {

    let settings: FilterSettings

    init(settings: FilterSettings) {
        self.settings = settings
    }

    /// Returns the block reason if the video should be filtered out, nil otherwise.
    /// Priority order: badData → insult → clickbait → exclamation → keyword → tag
    /// → category → partition → upBlocked → duration → japanese
    func shouldBlock(_ video: Video) -> BlockReason? {
        // 0. 空白视频硬拦截 — 没有封面/没有 bvid 的卡片肯定打不开，直接过滤
        if video.cover.trimmingCharacters(in: .whitespaces).isEmpty
            || video.id.trimmingCharacters(in: .whitespaces).isEmpty
            || video.title.trimmingCharacters(in: .whitespaces).isEmpty {
            return .badData
        }

        // 1. Insult / derogatory word filtering (matches title & UP主 name)
        if settings.enableInsultWordFilter {
            let words = settings.activeInsultWords
            if !words.isEmpty {
                let haystack = video.title + " " + video.upName
                for word in words {
                    if !word.isEmpty && haystack.contains(word) {
                        return .insultWord
                    }
                }
            }
        }

        // 2. Clickbait / leading-title keyword filtering
        if settings.enableClickbaitFilter {
            let title = video.title
            for word in FilterSettings.builtInClickbaitWords {
                if title.contains(word) {
                    return .clickbait
                }
            }
        }

        // 2b. 连续 2+ 个 !/？/！/？ → 引导式标题 (!! / !!! / ?? / ???)
        //     以及单个 !/！ 单独出现（由 exclamationWords 词表覆盖）
        if settings.enableExclamationFilter {
            if hasExclamationSpam(in: video.title) {
                return .exclamationSpam
            }
            for word in FilterSettings.exclamationWords {
                if video.title.contains(word) {
                    return .exclamationSpam
                }
            }
        }

        // 3. General keyword filtering (title + upName + desc + category + tags)
        if settings.enableKeywordFilter {
            let keywords = settings.activeKeywords
            if !keywords.isEmpty {
                let haystack = keywordHaystack(for: video)
                for word in keywords {
                    if haystack.contains(word) {
                        return .keywordBlocked
                    }
                }
            }
        }

        // 4. Tag filtering（只匹配视频 tag，精准度高于关键词）
        // 首页推荐/热门接口本身不返回 tag，已由 BiliAPI.enrichMetadata 补齐；
        // 搜索接口自带 tag 字段，因此三条流都能命中。
        if settings.enableTagFilter, !video.tags.isEmpty {
            let tags = video.tags.map { $0.lowercased() }
            for blocked in settings.activeTags {
                for tag in tags where tag.contains(blocked) {
                    return .tagBlocked
                }
            }
        }

        // 5. Category / partition blacklist (exact match, case-insensitive)
        if settings.enableCategoryFilter {
            let category = video.category.lowercased()
            if !category.isEmpty {
                for blocked in settings.blockedCategories {
                    if blocked.lowercased() == category {
                        return .categoryBlocked
                    }
                }
            }
        }

        // 6. Partition blacklist (一级 / 二级分区, by Bilibili tid)
        if settings.enablePartitionFilter {
            if let reason = partitionBlockReason(for: video) {
                return reason
            }
        }

        // 7. UP主 mid blacklist
        if settings.enableUPBlockFilter, video.upMid != 0, settings.blockedUPMids.contains(video.upMid) {
            return .upBlocked
        }

        // 7.5. 博主类型过滤：基于已缓存的 CreatorProfile.type 判断。
        // 只在置信度 >= 0.4 时生效，避免单条视频误判把优质博主整个屏蔽。
        // .other 类型不在默认屏蔽列表中，不会误伤。
        // 白名单内的博主跳过此规则。
        if settings.enableCreatorTypeFilter, video.upMid != 0,
           settings.whitelistedCreators[video.upMid] == nil,
           let profile = settings.knownCreators[video.upMid],
           profile.type != .other,
           profile.confidence >= 0.4,
           settings.blockedCreatorTypes.contains(profile.type) {
            return .creatorTypeBlocked
        }

        // 8. Duration block (global): videos shorter than or equal to the max selected threshold
        if let threshold = settings.effectiveDurationThreshold, video.duration > 0, video.duration <= threshold {
            return .duration
        }

        // 9. Japanese characters in title
        if settings.enableJapaneseTitleFilter {
            if containsJapanese(video.title) {
                return .japaneseTitle
            }
        }

        // 10. Japanese characters in UP主 name
        if settings.enableJapaneseUPFilter {
            if containsJapanese(video.upName) {
                return .japaneseUP
            }
        }

        return nil
    }

    /// Resolve a video's partition against the 一级/二级分区 blacklist.
    /// Prefers the API-provided leaf `tid`; when it is missing (some feeds such
    /// as 首页推荐 return no partition), falls back to the partition name.
    private func partitionBlockReason(for video: Video) -> BlockReason? {
        var leafTid = video.tid
        if leafTid == 0, !video.category.isEmpty {
            leafTid = BiliZone.leafTid(forName: video.category) ?? 0
        }
        guard leafTid != 0 else { return nil }

        if let topTid = BiliZone.topTid(forLeaf: leafTid),
           settings.blockedTopZoneTids.contains(topTid) {
            return .partitionBlocked
        }
        if settings.blockedSubZoneTids.contains(leafTid) {
            return .partitionBlocked
        }
        return nil
    }

    /// 把视频的文本信息拼成一份 haystack，供关键词过滤使用。
    private func keywordHaystack(for video: Video) -> String {
        var parts: [String] = [video.title, video.upName, video.desc, video.category]
        parts.append(contentsOf: video.tags)
        return parts.joined(separator: " ").lowercased()
    }

    // MARK: - Exclamation spam detection

    /// 标题里连续出现 2 个及以上的 !/？/！/？ → 基本都是引导式标题
    private func hasExclamationSpam(in text: String) -> Bool {
        let target: CharacterSet = CharacterSet(charactersIn: "!?！？")
        var run = 0
        for scalar in text.unicodeScalars {
            if target.contains(scalar) {
                run += 1
                if run >= 2 { return true }
            } else {
                run = 0
            }
        }
        return false
    }

    /// Search-result specific filter: applies the global rules plus the search min-duration filter.
    /// - Parameter applyMinDuration: pass false for user search — user results carry
    ///   no duration (duration == 0), so applying a min-duration filter would block
    ///   every user and produce an empty "没有匹配内容" page.
    func shouldBlockInSearch(_ video: Video, applyMinDuration: Bool = true) -> BlockReason? {
        if let reason = shouldBlock(video) {
            return reason
        }
        if applyMinDuration, let minSec = settings.searchMinDurationSeconds, video.duration < minSec {
            return .duration
        }
        return nil
    }

    // MARK: - Japanese character detection

    /// Returns true if the string contains Japanese-specific scripts.
    /// IMPORTANT: only kana are checked. CJK Unified Ideographs (U+4E00–U+9FFF)
    /// are shared with Chinese, and CJK punctuation (U+3000–U+303F: 、。《》【】「」)
    /// is used by Chinese too — flagging those blocked nearly every Chinese title
    /// containing brackets or an ideographic comma.
    private func containsJapanese(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            // Hiragana
            if v >= 0x3041 && v <= 0x3096 { return true }
            // Katakana letters (skip U+30FB middle dot / U+30FC prolonged mark,
            // which are also used as decorative separators in Chinese titles)
            if v >= 0x30A1 && v <= 0x30FA { return true }
            // Katakana Phonetic Extensions
            if v >= 0x31F0 && v <= 0x31FF { return true }
            // Hiragana/Katakana small letter ranges
            if v >= 0x1B000 && v <= 0x1B12F { return true }
            // Kana Supplement
            if v >= 0x1B130 && v <= 0x1B16F { return true }
        }
        return false
    }
}
