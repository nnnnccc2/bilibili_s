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
    @discardableResult
    static func save(
        in context: ModelContext,
        accountName: String,
        sender: String,
        content: String,
        receivedAt: Date = Date()
    ) throws -> Account {
        let account = try findOrCreate(name: normalized(accountName), in: context)
        // 账号还没填注册手机号时，尝试从短信内容里识别出手机号自动补上。
        if account.phoneNumber.isEmpty, let phone = PhoneNumber.extract(from: content) {
            account.phoneNumber = phone
        }
        let message = SMSMessage(sender: sender, content: content, receivedAt: receivedAt, account: account)
        context.insert(message)
        try context.save()
        return account
    }

    /// 账号名去空白，留空时归入「未命名账号」。
    private static func normalized(_ accountName: String) -> String {
        let trimmed = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名账号" : trimmed
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
