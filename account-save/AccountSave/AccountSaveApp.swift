import SwiftUI
import UIKit

@main
struct AccountSaveApp: App {
    init() {
        // 搜索框取消按钮固定显示为中文「取消」。
        let searchBar = UISearchBar.appearance()
        searchBar.tintColor = .systemBlue
        let cancelButton = UIButton.appearance(whenContainedInInstancesOf: [UISearchBar.self])
        cancelButton.setTitle("取消", for: .normal)
    }

    var body: some Scene {
        WindowGroup {
            SMSInboxView()
        }
        .modelContainer(AppStore.container)
    }
}
