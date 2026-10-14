import WebKit

// MARK: - POST body 跨进程丢失的补传存储
final class BodyStore {
    static let shared = BodyStore()
    private var dict: [String: Data] = [:]
    private let lock = NSLock()

    func set(id: String, data: Data) {
        lock.lock(); defer { lock.unlock() }
        dict[id] = data
    }
    func take(id: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        defer { dict.removeValue(forKey: id) }
        return dict[id]
    }
}

// MARK: - JS 消息桥
final class BiliBridge: NSObject, WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let dict = message.body as? [String: Any],
              let kind = dict["kind"] as? String else { return }
        switch kind {
        case "body":
            if let id = dict["id"] as? String,
               let b64 = dict["body"] as? String,
               let data = Data(base64Encoded: b64) {
                BodyStore.shared.set(id: id, data: data)
            }
        default:
            break
        }
    }
}

// MARK: - Scheme 代理
final class BiliSchemeHandler: NSObject, WKURLSchemeHandler {

    private let session: URLSession
    private let queue = DispatchQueue(label: "com.minibili.proxy")
    // schemeTask ↔ dataTask 映射，用于 stop 时取消
    private var runningTasks: [ObjectIdentifier: URLSessionDataTask] = [:]

    override init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 30
        cfg.httpAdditionalHeaders = nil
        self.session = URLSession(configuration: cfg)
        super.init()
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, url.scheme == "app" else {
            task.didFailWithError(URLError(.unsupportedURL))
            return
        }
        let path = url.path

        if path.hasPrefix("/api/") {
            // /api/x/... → https://api.bilibili.com/x/...
            forward(task: task, base: "https://api.bilibili.com", stripPrefix: "/api")
        } else if path.hasPrefix("/passport/") {
            // 登录相关接口走 passport 域
            forward(task: task, base: "https://passport.bilibili.com", stripPrefix: nil)
        } else {
            serveStatic(task: task, url: url)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        queue.async { [weak self] in
            guard let self else { return }
            if let dt = self.runningTasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask)) {
                dt.cancel()
            }
        }
    }

    // MARK: 转发到 B 站真实服务器
    private func forward(task: WKURLSchemeTask, base: String, stripPrefix: String?) {
        guard let url = task.request.url else { return }

        var path = url.path
        if let strip = stripPrefix, path.hasPrefix(strip) {
            path = String(path.dropFirst(strip.count))
        }
        guard var comps = URLComponents(string: base) else {
            task.didFailWithError(URLError(.badURL)); return
        }
        comps.path = path
        comps.percentEncodedQuery = url.percentEncodedQuery
        guard let realURL = comps.url else {
            task.didFailWithError(URLError(.badURL)); return
        }

        var req = URLRequest(url: realURL)
        req.httpMethod = task.request.httpMethod ?? "GET"

        // WKWebView 跨进程会丢 httpBody —— 用 JS 预传的 body 恢复
        if let bodyID = task.request.value(forHTTPHeaderField: "X-Bili-Body-ID"),
           let body = BodyStore.shared.take(id: bodyID) {
            req.httpBody = body
            req.setValue("application/x-www-form-urlencoded",
                         forHTTPHeaderField: "Content-Type")
        } else if let body = task.request.httpBody {
            req.httpBody = body
        }

        // 伪装成官网环境
        req.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent")
        req.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        // 登录态：JS 把 Cookie 通过自定义头传来，这里转正
        if let cookie = task.request.value(forHTTPHeaderField: "X-Bili-Cookie"),
           !cookie.isEmpty {
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let dataTask = session.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            self.queue.async {
                self.runningTasks.removeValue(forKey: ObjectIdentifier(task))
            }
            if let error {
                DispatchQueue.main.async { task.didFailWithError(error) }
                return
            }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  let schemeURL = task.request.url else {
                DispatchQueue.main.async {
                    task.didFailWithError(URLError(.badServerResponse))
                }
                return
            }
            // URLSession 已自动解压，不回传 Content-Encoding；
            // 补 ACAO 头让 JS 侧 fetch 不报警
            let headers: [String: String] = [
                "Content-Type": http.value(forHTTPHeaderField: "Content-Type")
                    ?? "application/json",
                "Access-Control-Allow-Origin": "*"
            ]
            let resp = HTTPURLResponse(
                url: schemeURL,
                statusCode: http.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers)!

            DispatchQueue.main.async {
                task.didReceive(resp)
                task.didReceive(data)
                task.didFinish()
            }
        }
        queue.async { [weak self] in
            self?.runningTasks[ObjectIdentifier(task)] = dataTask
        }
        dataTask.resume()
    }

    // MARK: 静态文件（index.html）
    private func serveStatic(task: WKURLSchemeTask, url: URL) {
        let rawPath = url.path
        let name = (rawPath == "/" || rawPath.isEmpty)
            ? "index" : String(rawPath.dropFirst())
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension.isEmpty
            ? "html" : (name as NSString).pathExtension

        var fileURL = Bundle.main.url(forResource: base, withExtension: ext)
        if fileURL == nil {
            fileURL = Bundle.main.url(forResource: base, withExtension: ext,
                                      subdirectory: "Resources")
        }
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime = ["html": "text/html", "js": "application/javascript",
                    "css": "text/css", "json": "application/json",
                    "png": "image/png", "svg": "image/svg+xml"][ext]
            ?? "application/octet-stream"
        let resp = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": mime])!
        task.didReceive(resp)
        task.didReceive(data)
        task.didFinish()
    }
}
