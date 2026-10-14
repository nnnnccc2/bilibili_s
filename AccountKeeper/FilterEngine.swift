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
    /// Priority order: insult word > clickbait > japanese title > japanese UP > duration
    func shouldBlock(_ video: Video) -> BlockReason? {
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

    /// Search-result specific filter: applies the global rules plus the search min-duration filter.
    func shouldBlockInSearch(_ video: Video) -> BlockReason? {
        if let reason = shouldBlock(video) {
            return reason
        }
        if let minSec = settings.searchMinDurationSeconds, video.duration < minSec {
            return .duration
        }
        return nil
    }

    // MARK: - Japanese character detection

    /// Returns true if the string contains Japanese-specific scripts.
    /// IMPORTANT: Do NOT include CJK Unified Ideographs (U+4E00–U+9FFF) — they
    /// are shared with Chinese and would falsely flag every Chinese video.
    /// Only detects kana and Japanese-only punctuation/symbols.
    private func containsJapanese(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            // Hiragana
            if v >= 0x3040 && v <= 0x309F { return true }
            // Katakana
            if v >= 0x30A0 && v <= 0x30FF { return true }
            // Katakana Phonetic Extensions
            if v >= 0x31F0 && v <= 0x31FF { return true }
            // Hiragana/Katakana small letter ranges
            if v >= 0x1B000 && v <= 0x1B12F { return true }
            // Kana Supplement
            if v >= 0x1B130 && v <= 0x1B16F { return true }
            // Small Kana Extension
            if v >= 0x1B170 && v <= 0x1B2FF { return true }
            // Enclosed Ideographic Supplement (contains 🈁 etc., Japanese-specific)
            if v >= 0x1F200 && v <= 0x1F2FF { return true }
            // Japanese-specific punctuation (「」『』、。 etc.) — U+3000–U+303F
            // Exclude ideographic space (U+3000) itself but keep the rest
            if v > 0x3000 && v <= 0x303F { return true }
        }
        return false
    }
}
