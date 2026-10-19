import SwiftUI

@main
struct AccountSaveApp: App {
    var body: some Scene {
        WindowGroup {
            SMSInboxView()
        }
        .modelContainer(AppStore.container)
    }
}
