//
//  AccountItem.swift
//  AccountKeeper
//
//  Account data model
//

import Foundation

struct AccountItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String          // 应用/网站名称
    var username: String      // 账号
    var password: String      // 密码（可选记录）
    var url: String           // 网址
    var note: String          // 备注
    var category: String      // 分类
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         name: String = "",
         username: String = "",
         password: String = "",
         url: String = "",
         note: String = "",
         category: String = "其他",
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.username = username
        self.password = password
        self.url = url
        self.note = note
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let categories = ["社交", "购物", "工作", "金融", "娱乐", "学习", "工具", "其他"]
}
