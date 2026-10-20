import Foundation
import SwiftData

/// 全局唯一的本地数据库，App 界面与快捷指令动作共用。
enum AppStore {
    static let container: ModelContainer = {
        let schema = Schema([Account.self, SMSMessage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("无法创建本地数据库：\(error)")
        }
    }()
}

/// 短信写入逻辑。
enum SMSSaver {
    /// 把一条短信保存到指定账号下；账号不存在时自动新建。
    /// recipient 为接收短信的手机号（注册手机号），优先填入账号的 phoneNumber。
    @discardableResult
    static func save(
        in context: ModelContext,
        accountName: String,
        sender: String,
        content: String,
        recipient: String = "",
        receivedAt: Date = Date()
    ) throws -> Account {
        let account = try findOrCreate(name: normalized(accountName, content: content), in: context)
        // 账号的注册手机号优先使用收件人参数；否则尝试从短信内容里识别。
        if account.phoneNumber.isEmpty {
            let recipientTrimmed = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
            if !recipientTrimmed.isEmpty {
                account.phoneNumber = recipientTrimmed
            } else if let phone = PhoneNumber.extract(from: content) {
                account.phoneNumber = phone
            }
        }
        let message = SMSMessage(sender: sender, content: content, receivedAt: receivedAt, account: account)
        context.insert(message)
        try context.save()
        return account
    }

    /// 账号名去空白，留空时尝试从短信内容【】中提取，仍无则归入「未命名账号」。
    private static func normalized(_ accountName: String, content: String = "") -> String {
        let trimmed = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let extracted = extractBracketName(from: content) {
            return extracted
        }
        return "未命名账号"
    }

    /// 从短信内容中提取第一个【...】里的文本作为账号名。
    private static func extractBracketName(from content: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "【([^】]+)】") else { return nil }
        let range = NSRange(content.startIndex..., in: content)
        guard let match = regex.firstMatch(in: content, range: range),
              let r = Range(match.range(at: 1), in: content) else { return nil }
        let name = String(content[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private static func findOrCreate(name: String, in context: ModelContext) throws -> Account {
        var descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let account = Account(name: name)
        context.insert(account)
        return account
    }
}
