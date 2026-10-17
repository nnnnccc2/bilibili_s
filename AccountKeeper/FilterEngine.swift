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
    /// Priority order: badData (必拦) → insult → clickbait → !!连续 → japanese → duration
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

        // 3. Japanese characters in title
        if settings.enableJapaneseTitleFilter {
            if containsJapanese(video.title) {
                return .japaneseTitle
            }
        }

        // 4. Japanese characters in UP主 name
        if settings.enableJapaneseUPFilter {
            if containsJapanese(video.upName) {
                return .japaneseUP
            }
        }

        // 5. Duration block (global): videos shorter than or equal to the max selected threshold
        if let threshold = settings.effectiveDurationThreshold, video.duration > 0, video.duration <= threshold {
            return .duration
        }

        return nil
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
