import SwiftUI

@main
struct MiniBiliWebApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 底部 Tab 栏贴到屏幕底缘（配合 safe-area-inset）
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
