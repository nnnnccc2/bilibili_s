import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        WebView()
    }
}

struct WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // ① 注册自定义 scheme —— 整个方案的基石
        config.setURLSchemeHandler(BiliSchemeHandler(), forURLScheme: "app")

        // ② JS → 原生消息桥（用于 POST body 跨进程补传）
        config.userContentController.add(BiliBridge(), name: "bili")

        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.allowsInlineMediaPlayback = true   // iOS 内联播放（playsinline）
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .systemBackground
        webView.isOpaque = true
        webView.allowsBackForwardNavigationGestures = true   // 边缘右滑返回
        webView.allowsLinkPreview = false
        // 伪装成真实 Safari，降低被风控识别为内嵌 WebView 的概率
        webView.customUserAgent =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        // 主页面与所有 API 请求同源（app://local），CORS 不触发
        webView.load(URLRequest(url: URL(string: "app://local/index.html")!))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
