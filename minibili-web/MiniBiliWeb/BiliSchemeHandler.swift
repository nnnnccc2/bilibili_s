import Foundation
import WebKit

/// 核心代理层。拦截 app:// 请求：
/// - app://local/*        → 从 App Bundle 提供本地静态资源（index.html 等）
/// - app://local/api/*    → 反向代理到 https://api.bilibili.com/*
/// - app://local/passport/* → 反向代理到 https://passport.bilibili.com/*
///
/// 代理时统一注入 Cookie、Referer、Origin 与移动端 UA，
/// 规避前端从 app:// 源直连 B 站接口时的跨域与风控问题。
final class BiliSchemeHandler: NSObject, WKURLSchemeHandler {

    private let session: URLSession

    override init() {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: config)
        super.init()
    }

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, url.scheme == "app" else {
            task.didFailWithError(URLError(.unsupportedURL))
            return
        }

        let path = url.path
        if path.hasPrefix("/api/") {
            forward(task, url: url, host: "https://api.bilibili.com", stripPrefix: "/api")
        } else if path.hasPrefix("/passport/") {
            forward(task, url: url, host: "https://passport.bilibili.com", stripPrefix: "")
        } else {
            serveStatic(task, url: url)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    // MARK: - 反向代理

    private func forward(_ task: WKURLSchemeTask, url: URL, host: String, stripPrefix: String) {
        var path = url.path
        if !stripPrefix.isEmpty, path.hasPrefix(stripPrefix) {
            path = String(path.dropFirst(stripPrefix.count))
        }

        var dest = URLComponents(string: host)!
        dest.path = path
        dest.query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.query

        guard let finalURL = dest.url else {
            task.didFailWithError(URLError(.badURL))
            return
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = task.request.httpMethod ?? "GET"
        request.httpBody = task.request.httpBody
        request.timeoutInterval = 20

        // 透传前端的自定义请求头（跳过受限头）
        for (key, value) in task.request.allHTTPHeaderFields ?? [:] {
            let lower = key.lowercased()
            if lower == "cookie" || lower == "x-bili-cookie" || lower == "host" { continue }
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 前端通过 X-Bili-Cookie 传递登录态，转换为真实 Cookie 头
        if let cookie = task.request.value(forHTTPHeaderField: "X-Bili-Cookie"), !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Origin")
        request.setValue(Self.mobileUA, forHTTPHeaderField: "User-Agent")

        let dataTask = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    task.didFailWithError(error)
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    task.didFailWithError(URLError(.badServerResponse))
                    return
                }

                var headers: [String: String] = [:]
                for (key, value) in http.allHeaderFields {
                    if let key = key as? String, let value = value as? String {
                        headers[key] = value
                    }
                }
                headers["Access-Control-Allow-Origin"] = "*"

                guard let response = HTTPURLResponse(
                    url: url,
                    statusCode: http.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                ) else {
                    task.didFailWithError(URLError(.badServerResponse))
                    return
                }

                task.didReceive(response)
                if let data = data { task.didReceive(data) }
                task.didFinish()
            }
        }
        dataTask.resume()
    }

    // MARK: - 静态资源

    private func serveStatic(_ task: WKURLSchemeTask, url: URL) {
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }

        let file = (path as NSString).lastPathComponent
        let ext = (file as NSString).pathExtension
        let base = (file as NSString).deletingPathExtension

        let resourceURL = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? nil : ext)
            ?? Bundle.main.url(forResource: "index", withExtension: "html")

        guard let resource = resourceURL, let data = try? Data(contentsOf: resource) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let headers: [String: String] = [
            "Content-Type": Self.mimeType(forExtension: ext),
            "Content-Length": "\(data.count)",
            "Access-Control-Allow-Origin": "*"
        ]
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) else {
            task.didFailWithError(URLError(.badServerResponse))
            return
        }
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    private static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "js": return "application/javascript; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        default: return "application/octet-stream"
        }
    }

    private static let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
}
