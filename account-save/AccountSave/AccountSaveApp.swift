import SwiftUI
import UIKit

@main
struct AccountSaveApp: App {
    init() {
        // 搜索框样式统一，取消按钮固定显示为中文「取消」。
        let searchBar = UISearchBar.appearance()
        searchBar.tintColor = .systemBrown
        let cancelButton = UIButton.appearance(whenContainedInInstancesOf: [UISearchBar.self])
        cancelButton.setTitle("取消", for: .normal)

        // 导航栏标题使用衬线字体，营造账本质感。
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        let serifTitle = UIFont(descriptor: UIFontDescriptor(name: "NewYork-Semibold", size: 17), size: 17)
            ?? UIFont.systemFont(ofSize: 17, weight: .semibold)
        navAppearance.titleTextAttributes = [.font: serifTitle]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .systemBrown
    }

    var body: some Scene {
        WindowGroup {
            SMSInboxView()
        }
        .modelContainer(AppStore.container)
    }
}
