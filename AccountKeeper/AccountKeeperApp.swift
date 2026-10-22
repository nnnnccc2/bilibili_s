//
//  AccountKeeperApp.swift
//  BiliBili
//
//  App entry point for the BiliBili third-party client
//

import SwiftUI

// MARK: - Bilibili theme colors (MiniBili-style clean theme)

extension Color {
    /// Primary brand blue (#0DA2E7) — matches the reference design
    static let biliBlue = Color(red: 13/255, green: 162/255, blue: 231/255)
    /// Page background (#F5FBFF)
    static let biliBackground = Color(red: 245/255, green: 251/255, blue: 255/255)
    /// Hero background behind the top bar (#A7D8F0)
    static let biliHero = Color(red: 167/255, green: 216/255, blue: 240/255)
    /// Card surface color — pure white
    static let biliCard = Color.white
    /// Subtle border for cards
    static let biliBorder = Color(red: 230/255, green: 232/255, blue: 235/255)
    /// Primary text (#0F172A)
    static let biliText = Color(red: 15/255, green: 23/255, blue: 42/255)
    /// Secondary text (#65758B)
    static let biliSubtext = Color(red: 101/255, green: 117/255, blue: 139/255)
    /// Unselected tab text (#475569)
    static let biliTabText = Color(red: 71/255, green: 85/255, blue: 105/255)
    /// Muted icon (#94A3B8)
    static let biliMuted = Color(red: 148/255, green: 163/255, blue: 184/255)
    /// Muted surface / placeholder (#F1F5F9)
    static let biliMutedSurface = Color(red: 241/255, green: 245/255, blue: 249/255)
}

/// Page background — solid clean color (no heavy gradient for performance)
let biliBackgroundGradient = Color.biliBackground

@main
struct BiliBiliApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 崩溃定位：记录最后渲染位置，闪退后下次启动可在首页弹窗查看。
        CrashReporter.install()
        CrashReporter.beginSession()
        // Large shared URL cache so cover/avatar images load instantly on
        // scroll-back and do not cause jank from repeated network fetches.
        let memoryCap = 64 * 1024 * 1024   // 64 MB in-memory
        let diskCap = 256 * 1024 * 1024     // 256 MB on-disk
        let cache = URLCache(memoryCapacity: memoryCap, diskCapacity: diskCap, diskPath: "BiliBiliImages")
        URLCache.shared = cache
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    // 设置写盘做了防抖，进入后台时立即落盘避免丢失最后一次修改。
                    if phase != .active { store.flushSettings() }
                    if phase == .background { CrashReporter.endSession() }
                }
        }
    }
}

// MARK: - 崩溃定位（仅用于排查闪退）

/// 记录「最后渲染到的位置」与未捕获异常，闪退后重启 App 会在首页提示，
/// 便于在不接线的条件下定位到具体卡片。
enum CrashReporter {

    private static let markerKey = "bili.crash.marker"
    private static let detailKey = "bili.crash.detail"
    private static let sessionKey = "bili.crash.sessionOpen"
    private static let pendingKey = "bili.crash.pending"

    private static var lastWritten = ""

    static func install() {
        NSSetUncaughtExceptionHandler { exception in
            let marker = UserDefaults.standard.string(forKey: markerKey) ?? "-"
            let detail = """
            异常：\(exception.name.rawValue)
            原因：\(exception.reason ?? "-")
            位置：\(marker)

            \(exception.callStackSymbols.prefix(30).joined(separator: "\n"))
            """
            UserDefaults.standard.set(detail, forKey: detailKey)
            UserDefaults.standard.synchronize()
        }
    }

    /// 启动时调用：上一次运行未正常结束则把最后位置记为待展示信息。
    static func beginSession() {
        let wasRunning = UserDefaults.standard.bool(forKey: sessionKey)
        let marker = UserDefaults.standard.string(forKey: markerKey) ?? ""
        if wasRunning, !marker.isEmpty {
            let detail = UserDefaults.standard.string(forKey: detailKey) ?? ""
            UserDefaults.standard.set(
                detail.isEmpty ? "上次崩溃位置：\(marker)" : detail,
                forKey: pendingKey
            )
        }
        UserDefaults.standard.set(true, forKey: sessionKey)
    }

    static func endSession() {
        UserDefaults.standard.set(false, forKey: sessionKey)
        UserDefaults.standard.synchronize()
    }

    /// 记录渲染位置（同一位置不重复写盘）。
    static func mark(_ location: String) {
        guard location != lastWritten else { return }
        lastWritten = location
        UserDefaults.standard.set(location, forKey: markerKey)
    }

    /// 取出并清空待展示的定位信息。
    static func takePending() -> String? {
        guard let text = UserDefaults.standard.string(forKey: pendingKey),
              !text.isEmpty else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingKey)
        return text
    }
}

extension View {
    /// 渲染时记录崩溃定位标记。
    func crashMark(_ name: String) -> some View {
        CrashReporter.mark(name)
        return self
    }
}
