import SwiftUI

@main
struct MiniBiliWebApp: App {
    var body: some Scene {
        WindowGroup {
            WebView()
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
