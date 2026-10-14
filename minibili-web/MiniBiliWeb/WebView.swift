import SwiftUI
import WebKit

/// WKWebView 封装：
/// 加载打包在 App Bundle 内的本地前端（app://local/index.html），
/// 并注册自定义 scheme 代理层 BiliSchemeHandler。
struct WebView: UIViewRepresentable {

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // 注册自定义 URL Scheme，用于承载本地静态资源与 B 站接口代理
        config.setURLSchemeHandler(BiliSchemeHandler(), forURLScheme: "app")

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences

        // 允许内联播放，且无需用户手势即可自动播放
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        if let url = URL(string: "app://local/index.html") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
