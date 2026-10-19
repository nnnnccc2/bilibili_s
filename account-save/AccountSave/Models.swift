import Foundation
import SwiftData

/// 账号条目：账号名由快捷指令弹窗输入，注册手机号在 App 内维护。
@Model
final class Account {
    var name: String
    var phoneNumber: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SMSMessage.account)
    var messages: [SMSMessage] = []

    init(name: String, phoneNumber: String = "", createdAt: Date = Date()) {
        self.name = name
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
    }
}

extension Account {
    /// 该账号下的短信，按接收时间倒序。
    var sortedMessages: [SMSMessage] {
        messages.sorted { $0.receivedAt > $1.receivedAt }
    }

    var latestMessage: SMSMessage? {
        sortedMessages.first
    }

    /// 该账号下出现过的发件号码数量。
    var senderCount: Int {
        Set(messages.map(\.sender)).count
    }

    /// 展示用的手机号文案。
    var phoneNumberText: String {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "未填写" : trimmed
    }
}

/// 一条已保存的短信。
@Model
final class SMSMessage {
    var sender: String
    var content: String
    var receivedAt: Date
    var account: Account?

    init(sender: String, content: String, receivedAt: Date = Date(), account: Account? = nil) {
        self.sender = sender
        self.content = content
        self.receivedAt = receivedAt
        self.account = account
    }

    var senderText: String {
        let trimmed = sender.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未知号码" : trimmed
    }
}
