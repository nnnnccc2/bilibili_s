//
//  User.swift
//  BiliBili
//
//  User account model
//

import Foundation

struct User: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var avatar: String
    var level: Int
    var isVip: Bool
    var coins: Int
    var phone: String

    init(id: String = "",
         name: String = "纯净观影官",
         avatar: String = "",
         level: Int = 6,
         isVip: Bool = true,
         coins: Int = 233,
         phone: String = "") {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.level = level
        self.isVip = isVip
        self.coins = coins
        self.phone = phone
    }

    /// Masked phone number e.g. "138****8888"
    var maskedPhone: String {
        guard phone.count >= 7 else { return phone }
        let start = phone.index(phone.startIndex, offsetBy: 3)
        let end = phone.index(phone.startIndex, offsetBy: 7)
        return phone.replacingCharacters(in: start..<end, with: "****")
    }
}
