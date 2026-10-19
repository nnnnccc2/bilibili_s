import Foundation

/// 从短信内容里提取验证码。
enum VerificationCode {
    private static let keywords = ["验证码", "校验码", "动态码", "安全码", "口令", "code", "Code", "CODE"]
    /// 无关键词时，只有出现这些语义的短信才允许退化为「取第一个 4~6 位数字」。
    private static let fallbackContexts = ["验证", "校验", "登录", "动态", "安全", "口令", "code", "Code", "CODE"]

    /// 优先取「验证码」等关键词后的数字；没有关键词时，仅在疑似验证类短信里取第一个 4~6 位数字。
    static func extract(from content: String) -> String? {
        if let code = match(pattern: keywordPattern, in: content) {
            return code
        }
        guard fallbackContexts.contains(where: { content.contains($0) }) else {
            return nil
        }
        return match(pattern: "(?<![0-9])([0-9]{4,6})(?![0-9])", in: content)
    }

    private static var keywordPattern: String {
        let alternatives = keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        return "(?:\(alternatives))[^0-9]{0,8}?([0-9]{4,8})"
    }

    private static func match(pattern: String, in content: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(content.startIndex..., in: content)
        guard let result = expression.firstMatch(in: content, range: range),
              result.numberOfRanges > 1,
              let codeRange = Range(result.range(at: 1), in: content) else {
            return nil
        }
        return String(content[codeRange])
    }
}

/// 时间展示与导出共用的格式化。
enum DateText {
    private static let absoluteFormatter = makeFormatter("M月d日 HH:mm")
    private static let fullFormatter = makeFormatter("yyyy-MM-dd HH:mm:ss")
    private static let stampFormatter = makeFormatter("yyyyMMdd_HHmmss")

    /// 列表里的相对时间，如「30 分钟前」；超过一天显示具体日期。
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60)) 分钟前" }
        if seconds < 86400 { return "\(Int(seconds / 3600)) 小时前" }
        return absolute(date)
    }

    /// 详情页展示的时间，如「10月18日 23:27」。
    static func absolute(_ date: Date) -> String {
        absoluteFormatter.string(from: date)
    }

    /// 导出文件里的完整时间。
    static func full(_ date: Date) -> String {
        fullFormatter.string(from: date)
    }

    /// 生成文件名用的时间戳。
    static func stamp(_ date: Date = Date()) -> String {
        stampFormatter.string(from: date)
    }

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter
    }
}
