import SwiftUI
import UIKit

@main
struct AccountSaveApp: App {
    init() {
        // 搜索框右侧取消按钮固定显示为中文「取消」。
        UISearchBar.appearance().setValue("取消", forKey: "cancelButtonText")
    }

    var body: some Scene {
        WindowGroup {
            SMSInboxView()
        }
        .modelContainer(AppStore.container)
    }
}
