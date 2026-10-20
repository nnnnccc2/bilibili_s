//
//  BiliAPI.swift
//  BiliBili
//
//  Real Bilibili API integration with WBI signing
//

import Foundation
import CommonCrypto
import AVFoundation

// MARK: - Shared enums

enum HomeCategory: String, CaseIterable, Identifiable {
    case recommend = "推荐"
    case hot = "热门"
    case live = "直播"
    case cinema = "影视"
    var id: String { rawValue }
}

enum Partition: String, CaseIterable, Identifiable {
    case anime = "番剧动画"
    case music = "音乐现场"
    case dance = "舞蹈特区"
    case game = "游戏中心"
    case knowledge = "知识学堂"
    case tech = "科技数码"
    case life = "日常生活"
    case guichu = "鬼畜搞笑"
    case fashion = "时尚美妆"
    case auto = "汽车出行"
    case cinema = "影视剧场"
    case entertainment = "娱乐综艺"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .anime: return "film"
        case .music: return "music.note"
        case .dance: return "sparkles"
        case .game: return "gamecontroller"
        case .knowledge: return "book"
        case .tech: return "cpu"
        case .life: return "cup.and.saucer"
        case .guichu: return "face.smiling"
        case .fashion: return "tshirt"
        case .auto: return "car"
        case .cinema: return "tv"
        case .entertainment: return "smiley"
        }
    }
}

enum SearchType: String, CaseIterable, Identifiable {
    case video = "视频"
    case user = "用户"
    var id: String { rawValue }
}

/// Bilibili API endpoints and networking
final class BiliAPI {
    static let shared = BiliAPI()

    private let session: URLSession
    private let baseHeaders: [String: String] = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
        "Referer": "https://www.bilibili.com/"
    ]

    /// Cookies after login (SESSDATA, bili_jct, DedeUserID, etc.)
    var cookies: [String: String] = [:] {
        didSet { saveCookies() }
    }

    /// Visitor cookies (buvid3, buvid4, b_nut). Persisted so a real server-issued
    /// set survives launches — Bilibili's search endpoint returns a risk-control
    /// HTML page (→ empty "没有匹配内容") when buvid3/buvid4 are missing.
    private var visitorCookies: [String: String] = [:] {
        didSet { syncWBISignerCookie(); saveVisitorCookies() }
    }

    /// Keep WBISigner's cookie in sync so its nav/key fetch carries buvid3.
    private func syncWBISignerCookie() {
        var all = visitorCookies
        for (k, v) in cookies { all[k] = v }
        WBISigner.shared.cookieHeader = all.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    /// Cache of resolved playable streams keyed by bvid, so playback is instant on tap.
    private var streamCache: [String: PlayableStream] = [:]
    /// Insertion order of `streamCache` keys, used to bound the cache size.
    private var streamOrder: [String] = []
    /// Max cached streams. Each DASH entry holds an `AVAsset`, so don't let the
    /// cache grow without bound over a long session.
    private let streamCacheLimit = 80

    /// Store a resolved stream, evicting the oldest entries once over the cap.
    private func cacheStream(_ stream: PlayableStream, for id: String) {
        if streamCache[id] == nil { streamOrder.append(id) }
        streamCache[id] = stream
        if streamOrder.count > streamCacheLimit {
            let overflow = streamOrder.count - streamCacheLimit
            for _ in 0..<overflow { streamCache[streamOrder.removeFirst()] = nil }
        }
    }

    /// CSRF token (bili_jct) required for POST actions like follow/like/coin.
    var csrf: String { cookies["bili_jct"] ?? "" }

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        self.session = URLSession(configuration: config)
        loadCookies()
        loadVisitorCookies()
        // Ensure a full visitor-cookie set exists IMMEDIATELY so the first API call
        // we make (search / popular / live / cinema return a risk-control page
        // without buvid3+buvid4) always carries one. Real values from finger/spi
        // overwrite these synthetic fallbacks once fetched.
        if (visitorCookies["buvid3"] ?? "").isEmpty {
            visitorCookies["buvid3"] = Self.generateBuvid3()
        }
        if (visitorCookies["buvid4"] ?? "").isEmpty {
            visitorCookies["buvid4"] = Self.generateBuvid4()
        }
        if (visitorCookies["b_nut"] ?? "").isEmpty {
            visitorCookies["b_nut"] = String(Int(Date().timeIntervalSince1970))
        }
        fetchBuvid3()
    }

    // MARK: - Cookie helpers

    var cookieHeader: String {
        var all = visitorCookies
        for (k, v) in cookies { all[k] = v }
        return all.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    /// Generate a synthetic buvid3 in Bilibili's format:
    ///   XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX{unix_ts}infoc
    /// Used as an immediate fallback so the first request isn't blocked by -352.
    private static func generateBuvid3() -> String {
        let hex = "0123456789ABCDEF"
        func rand(_ n: Int) -> String {
            String((0..<n).map { _ in hex.randomElement()! })
        }
        let uuid = "\(rand(8))-\(rand(4))-\(rand(4))-\(rand(4))-\(rand(12))"
        let ts = String(Int(Date().timeIntervalSince1970))
        return "\(uuid)\(ts)infoc"
    }

    /// Synthetic buvid4 fallback in Bilibili's format. Used only until the real
    /// one arrives from finger/spi.
    private static func generateBuvid4() -> String {
        let hex = "0123456789ABCDEF"
        func rand(_ n: Int) -> String {
            String((0..<n).map { _ in hex.randomElement()! })
        }
        let uuid = "\(rand(8))-\(rand(4))-\(rand(4))-\(rand(4))-\(rand(12))"
        let ts = String(Int(Date().timeIntervalSince1970))
        return "\(uuid)\(ts)-\(rand(7))-\(rand(10))"
    }

    /// Fetch real buvid3/buvid4 visitor IDs required by anti-bot checks.
    /// Retries up to `retry` times on failure. When `completion` is supplied it is
    /// always called exactly once (on the main queue) after the fetch finishes —
    /// used to retry a request that hit a risk-control page.
    private func fetchBuvid3(retry: Int = 3, completion: (() -> Void)? = nil) {
        guard let url = URL(string: "https://api.bilibili.com/x/frontend/finger/spi") else {
            DispatchQueue.main.async { completion?() }
            return
        }
        var req = URLRequest(url: url)
        for (k, v) in baseHeaders { req.setValue(v, forHTTPHeaderField: k) }
        session.dataTask(with: req) { [weak self] data, _, error in
            guard let self = self else { return }
            let retryLater: (() -> Void) = {
                if retry > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        self.fetchBuvid3(retry: retry - 1, completion: completion)
                    }
                } else {
                    DispatchQueue.main.async { completion?() }
                }
            }
            if error != nil {
                retryLater()
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let d = json["data"] as? [String: Any] else {
                retryLater()
                return
            }
            let b3 = d["b_3"] as? String
            let b4 = d["b_4"] as? String
            DispatchQueue.main.async {
                if let b3 = b3, !b3.isEmpty { self.visitorCookies["buvid3"] = b3 }
                if let b4 = b4, !b4.isEmpty { self.visitorCookies["buvid4"] = b4 }
                completion?()
            }
        }.resume()
    }

    private func loadCookies() {
        if let stored = UserDefaults.standard.dictionary(forKey: "BiliBili.cookies") as? [String: String] {
            cookies = stored
        }
    }

    private func saveCookies() {
        UserDefaults.standard.set(cookies, forKey: "BiliBili.cookies")
    }

    private func loadVisitorCookies() {
        if let stored = UserDefaults.standard.dictionary(forKey: "BiliBili.visitorCookies") as? [String: String] {
            visitorCookies = stored
        }
    }

    private func saveVisitorCookies() {
        UserDefaults.standard.set(visitorCookies, forKey: "BiliBili.visitorCookies")
    }

    func clearCookies() {
        cookies.removeAll()
        UserDefaults.standard.removeObject(forKey: "BiliBili.cookies")
    }

    // MARK: - Generic request

    /// Android-app-style user agent. Space endpoints accept this without WBI
    /// and return code=0 reliably (same approach PiliPlus uses).
    private static let appUserAgent = "Mozilla/5.0 BiliDroid/7.54.0 (bbcallen@gmail.com) os/android model/Pixel mobi_app/android build/7540000"
    
    /// Bilibili Android appkey/appsec (same pair PiliPlus uses for app signing).
    private static let appKey = "1d8b6e7d45233436"
    private static let appSec = "560c52ccd288fed045859ed18bffd973"
    
    /// App-side signature: add appkey + ts, sort by key, URL-encode, append
    /// appsec, MD5 — produces the `sign` field. Mirrors PiliPlus's AppSign.
    private static func appSign(_ params: [String: String]) -> [String: String] {
        var p = params
        p["appkey"] = appKey
        p["ts"] = String(Int(Date().timeIntervalSince1970))
        let sorted = p.sorted { $0.key < $1.key }
        let query = sorted.map {
            let k = $0.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.key
            let v = $0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        let sign = (query + appSec).data(using: .utf8)?.md5() ?? ""
        p["sign"] = sign
        return p
    }

    private func request(_ urlString: String, params: [String: String] = [:], useWBI: Bool = false, useAppUA: Bool = false, useAppSign: Bool = false, forceWBIRefresh: Bool = false, referer: String? = nil, ignoreCookies: Bool = false, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let build: (Bool) -> Void = { [weak self] hasKeys in
            guard let self = self else { return }
            var url: URL?
            if useWBI {
                // WBI-signed query string is already correctly percent-encoded;
                // set it directly to avoid double-encoding via URLQueryItem.
                let signed = WBISigner.shared.sign(params: params)
                var comps = URLComponents(string: urlString)
                comps?.percentEncodedQuery = signed
                url = comps?.url
            } else {
                let finalParams = useAppSign ? Self.appSign(params) : params
                var comps = URLComponents(string: urlString)
                comps?.queryItems = finalParams.map { URLQueryItem(name: $0.key, value: $0.value) }
                url = comps?.url
            }
            guard let finalURL = url else {
                completion(nil, nil, NSError(domain: "BiliAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                return
            }
            var req = URLRequest(url: finalURL)
            if useAppUA {
                req.setValue(Self.appUserAgent, forHTTPHeaderField: "User-Agent")
                req.setValue("cronet", forHTTPHeaderField: "bili-http-engine")
            } else {
                for (k, v) in self.baseHeaders { req.setValue(v, forHTTPHeaderField: k) }
            }
            if let referer = referer { req.setValue(referer, forHTTPHeaderField: "Referer") }
            if !ignoreCookies && !self.cookieHeader.isEmpty {
                req.setValue(self.cookieHeader, forHTTPHeaderField: "Cookie")
            }
            self.session.dataTask(with: req) { data, response, error in
                completion(data, response, error)
            }.resume()
        }

        if useWBI {
            WBISigner.shared.refreshKeysIfNeeded(force: forceWBIRefresh) { success in
                if success {
                    build(true)
                } else {
                    // WBI key fetch failed (network / nav blocked); retry once more
                    // after a short delay, then give up so the caller gets an error
                    // instead of a silently-bad signature.
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
                        WBISigner.shared.refreshKeysIfNeeded(force: true) { retrySuccess in
                            if retrySuccess {
                                build(true)
                            } else {
                                completion(nil, nil, NSError(domain: "BiliAPI", code: -10, userInfo: [NSLocalizedDescriptionKey: "WBI 密钥获取失败"]))
                            }
                        }
                    }
                }
            }
        } else {
            build(false)
        }
    }

    private func parseJSON(_ data: Data?) -> [String: Any]? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    /// POST request with URL-encoded form body (used for SMS login).
    private func postRequest(_ urlString: String, form: [String: String], completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil, nil, NSError(domain: "BiliAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        for (k, v) in baseHeaders { req.setValue(v, forHTTPHeaderField: k) }
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if !cookieHeader.isEmpty {
            req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        let body = form.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)
        session.dataTask(with: req) { data, response, error in
            completion(data, response, error)
        }.resume()
    }

    /// Normalize a cover URL to an https:// URL that iOS can load under ATS.
    internal static func coverURL(_ raw: String) -> String {
        if raw.hasPrefix("https://") { return raw }
        if raw.hasPrefix("http://") { return raw.replacingOccurrences(of: "http://", with: "https://") }
        if raw.hasPrefix("//") { return "https:" + raw }
        return raw
    }

    // MARK: - Home feed

    func fetchHome(category: HomeCategory, page: Int = 1, completion: @escaping ([Video]) -> Void) {
        // Every feed is post-processed so that videos missing partition metadata
        // (notably 首页推荐) get tid / 分区名 / 简介 回填，过滤引擎才有完整的匹配维度。
        let finish: ([Video]) -> Void = { [weak self] videos in
            guard let self = self else {
                DispatchQueue.main.async { completion(videos) }
                return
            }
            self.enrichMetadata(videos, completion: completion)
        }

        switch category {
        case .recommend:
            // Recommendation feed (WBI signed) — fresh_idx increments for pagination
            let params: [String: String] = [
                "fresh_type": "4",
                "feed_version": "V8",
                "ps": "20",
                "fresh_idx": String(page)
            ]
            request("https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd", params: params, useWBI: false) { [weak self] data, _, _ in
                finish(self?.parseRecommend(data) ?? [])
            }
        case .hot:
            let params: [String: String] = ["ps": "20", "pn": String(page)]
            request("https://api.bilibili.com/x/web-interface/popular", params: params) { [weak self] data, _, _ in
                finish(self?.parseVideoList(data) ?? [])
            }
        case .live:
            // Paginated live recommendations (page 1/2/3… return different rooms),
            // so both infinite scroll and pull-to-refresh surface new content.
            // The old index/getList endpoint had no page param and always returned
            // the same ~11 rooms, which is why refreshing appeared to do nothing.
            let params: [String: String] = ["page": String(page), "page_size": "20", "platform": "web"]
            request("https://api.live.bilibili.com/room/v1/room/get_user_recommend", params: params) { [weak self] data, _, _ in
                finish(self?.parseLive(data) ?? [])
            }
        case .cinema:
            // PGC cinema rank list (movies & TV)
            let params: [String: String] = ["season_type": "2", "day": "7"]
            request("https://api.bilibili.com/pgc/season/rank/web/list", params: params) { [weak self] data, _, _ in
                finish(self?.parseCinema(data) ?? [])
            }
        }
    }

    /// 元数据补拉结果，用于在首页「数据诊断」里直接显示失败原因。
    struct EnrichReport {
        var tagTried = 0
        var tagOK = 0
        var viewTried = 0
        var viewOK = 0
        /// 最后一次失败的接口错误码（B站 code，如 -101 / -352 / -404）
        var lastCode = 0
        var lastMessage = ""
        /// 最后一次失败的 HTTP 状态码与响应体片段，用于区分风控（412/HTML）/ 接口报错
        var lastStatus = 0
        var lastBody = ""
        var note: String {
            var s = "补tag \(tagOK)/\(tagTried) · 补分区 \(viewOK)/\(viewTried)"
            if lastStatus != 0 { s += " · HTTP\(lastStatus)" }
            if lastCode != 0 { s += " · code \(lastCode) \(lastMessage)" }
            if !lastBody.isEmpty { s += " · \(lastBody)" }
            return s
        }
    }

    /// 最近一次 enrichMetadata 的结果。completion 回调时已写入。
    private(set) var lastEnrichReport = EnrichReport()

    /// 首页推荐流（rcmd 接口）只返回标题 / UP主 / 封面，热门流虽然带 tid 但不带 tag，
    /// 导致「通用关键词过滤」和「分区屏蔽」在这两条流上命中率极低（搜索流自带
    /// tid/typename/tag，所以只有搜索"过滤有效"）。
    ///
    /// 这里对缺少分区 ID 的视频补拉 `/x/web-interface/view`（tid / 分区名 / 简介 / 时长），
    /// 对缺少 tag 的视频补拉 `/x/tag/archive/tags`（体积仅约 2KB/条）。
    /// 两者**并行**发起，避免"详情 → tag"串行把耗时翻倍导致兜底超时先触发、tag 丢失。
    /// 请求失败（常见于登录 cookie 里 SESSDATA 过期，接口回 -101/-352）时
    /// **去掉 cookie 重试一次**，用游客身份取公开元数据。
    /// 直播房间号、影视 season_id 等非 BV 形态的 ID 直接跳过。
    /// 12 秒兜底超时，避免个别慢请求卡住首页。completion 始终在主线程回调。
    func enrichMetadata(_ videos: [Video], completion: @escaping ([Video]) -> Void) {
        let targets = videos.indices.filter {
            videos[$0].id.hasPrefix("BV") && (videos[$0].tid == 0 || videos[$0].tags.isEmpty)
        }
        guard !targets.isEmpty else {
            DispatchQueue.main.async { completion(videos) }
            return
        }

        var result = videos
        var report = EnrichReport()
        let lock = NSLock()
        let group = DispatchGroup()
        var didFinish = false

        let finishOnce: () -> Void = {
            lock.lock()
            if didFinish {
                lock.unlock()
                return
            }
            didFinish = true
            let output = result
            let finalReport = report
            lock.unlock()
            DispatchQueue.main.async {
                self.lastEnrichReport = finalReport
                completion(output)
            }
        }

        // 兜底：12 秒内未全部返回也先交付已有数据，绝不卡住首页。
        DispatchQueue.global().asyncAfter(deadline: .now() + 12) { finishOnce() }

        for index in targets {
            let bvid = videos[index].id

            if videos[index].tid == 0 {
                group.enter()
                lock.lock(); report.viewTried += 1; lock.unlock()
                fetchViewMetadata(bvid: bvid, anonymous: false) { [weak self] payload, code, message, status, body in
                    defer { group.leave() }
                    guard let self = self else { return }
                    lock.lock()
                    if let payload = payload {
                        report.viewOK += 1
                        let tid = self.parseTid(payload["tid"])
                        let tname = payload["tname"] as? String ?? ""
                        if tid != 0 { result[index].tid = tid }
                        if result[index].category.isEmpty {
                            result[index].category = tname.isEmpty ? (BiliZone.leafName(tid) ?? "") : tname
                        }
                        if result[index].desc.isEmpty { result[index].desc = payload["desc"] as? String ?? "" }
                        if result[index].duration == 0 { result[index].duration = payload["duration"] as? Int ?? 0 }
                        if result[index].aid == 0 { result[index].aid = payload["aid"] as? Int ?? 0 }
                        if result[index].cid == 0 { result[index].cid = payload["cid"] as? Int ?? 0 }
                    } else {
                        report.lastCode = code
                        report.lastMessage = message
                        report.lastStatus = status
                        report.lastBody = body
                    }
                    lock.unlock()
                }
            }

            if videos[index].tags.isEmpty {
                group.enter()
                lock.lock(); report.tagTried += 1; lock.unlock()
                fetchTags(bvid: bvid, anonymous: false) { [weak self] names, code, message, status, body in
                    guard let self = self else { group.leave(); return }
                    if let names = names, !names.isEmpty {
                        lock.lock()
                        report.tagOK += 1
                        if result[index].tags.isEmpty { result[index].tags = names }
                        lock.unlock()
                        group.leave()
                        return
                    }
                    // 失败 → 去掉 cookie（游客身份）再试一次
                    self.fetchTags(bvid: bvid, anonymous: true) { names2, code2, message2, status2, body2 in
                        lock.lock()
                        if let names2 = names2, !names2.isEmpty {
                            report.tagOK += 1
                            if result[index].tags.isEmpty { result[index].tags = names2 }
                        } else {
                            report.lastCode = code2 != 0 ? code2 : code
                            report.lastMessage = message2.isEmpty ? message : message2
                            report.lastStatus = status2 != 0 ? status2 : status
                            report.lastBody = body2.isEmpty ? body : body2
                        }
                        lock.unlock()
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .global()) { finishOnce() }
    }

    /// 取视频公开详情（tid / tname / desc / duration）。
    private func fetchViewMetadata(bvid: String, anonymous: Bool, completion: @escaping ([String: Any]?, Int, String, Int, String) -> Void) {
        request("https://api.bilibili.com/x/web-interface/view", params: ["bvid": bvid], ignoreCookies: anonymous) { [weak self] data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = Self.snippet(data)
            guard let self = self, let json = self.parseJSON(data) else {
                completion(nil, -1, "无响应", status, body)
                return
            }
            let code = json["code"] as? Int ?? -1
            guard code == 0, let d = json["data"] as? [String: Any] else {
                completion(nil, code, json["message"] as? String ?? "", status, body)
                return
            }
            completion(d, 0, "", status, "")
        }
    }

    /// 取视频 tag 列表。
    private func fetchTags(bvid: String, anonymous: Bool, completion: @escaping ([String]?, Int, String, Int, String) -> Void) {
        request("https://api.bilibili.com/x/tag/archive/tags", params: ["bvid": bvid], ignoreCookies: anonymous) { [weak self] data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = Self.snippet(data)
            guard let self = self, let json = self.parseJSON(data) else {
                completion(nil, -1, "无响应", status, body)
                return
            }
            let code = json["code"] as? Int ?? -1
            guard code == 0, let list = json["data"] as? [[String: Any]] else {
                completion(nil, code, json["message"] as? String ?? "", status, body)
                return
            }
            let names = list.compactMap { $0["tag_name"] as? String }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            completion(names, names.isEmpty ? -2 : 0, names.isEmpty ? "tag为空" : "", status, names.isEmpty ? body : "")
        }
    }

    /// 响应体前 60 个字符，用于诊断（HTML 风控页 / JSON 错误码都能看出）。
    private static func snippet(_ data: Data?) -> String {
        guard let data = data, !data.isEmpty else { return "" }
        let text = String(decoding: data.prefix(200), as: UTF8.self)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(text.prefix(60))
    }

    // MARK: - Search

    /// Search Bilibili content.
    /// - Parameter minDurationSeconds: optional minimum duration in seconds.
    ///   For thresholds >= 10 min we use Bilibili's server-side duration buckets
    ///   (10-30 / 30-60 / 60+ min) and fetch every bucket at or above the
    ///   threshold, then combine + dedupe. If the server buckets come back empty
    ///   (risk control, or genuinely no long videos) we fall back to fetching all
    ///   and filtering client-side, so a duration filter never yields an
    ///   unexplained empty page. For thresholds < 10 min we fetch all and filter
    ///   client-side (only a tiny fraction of results get removed).
    func search(keyword: String, type: SearchType, page: Int = 1, minDurationSeconds: Int? = nil, completion: @escaping ([Video]) -> Void) {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion([])
            return
        }

        // Duration only ever applies to video search (user results have no duration).
        let minSec = (type == .video) ? minDurationSeconds : nil

        // Primary path: the web `/x/web-interface/search/type` endpoint. With the
        // visitor cookies (buvid3/buvid4) it is NOT risk-controlled and returns
        // 50 pure video results per page (the App endpoint mixes card types —
        // only ~12 of 20 are actually videos — which is why results looked
        // "incomplete"). It also supports server-side duration buckets.
        fetchSearchWeb(keyword: keyword, type: type, page: page, minSec: minSec) { [weak self] webVideos in
            guard let self = self else { return }
            if !webVideos.isEmpty {
                completion(webVideos)
                return
            }
            // Fallback: the App-signed `/x/v2/search` endpoint when the web
            // endpoint is risk-controlled or genuinely empty.
            self.fetchAppSearch(keyword: keyword, type: type, page: page) { appVideos in
                completion(Self.filterByMinDuration(appVideos, minSec))
            }
        }
    }

    /// Web search (primary path): pure video/user results with server-side
    /// duration buckets. `page_size` (not the legacy `ps`) is what the endpoint
    /// actually honours — `ps` is silently ignored and caps the page at 20.
    private func fetchSearchWeb(keyword: String, type: SearchType, page: Int, minSec: Int?, completion: @escaping ([Video]) -> Void) {
        let searchType = (type == .video) ? "video" : "bili_user"
        let params: [String: String] = [
            "search_type": searchType,
            "keyword": keyword,
            "page": String(page),
            "page_size": "50"
        ]
        let buckets = Self.durationBuckets(for: minSec)
        fetchSearchBuckets(buckets, params: params, type: type) { [weak self] videos in
            guard let self = self else { return }
            let filtered = Self.filterByMinDuration(videos, minSec)
            if filtered.isEmpty, buckets != [0] {
                // Server-side buckets were empty → fetch everything and filter
                // client-side so the user still gets results.
                self.fetchSearchBuckets([0], params: params, type: type) { all in
                    completion(Self.filterByMinDuration(all, minSec))
                }
            } else {
                completion(filtered)
            }
        }
    }

    /// Fetch one page from the App-signed search endpoint. Requires the Android
    /// `build` / `mobi_app` / `platform` params — without them the API returns
    /// `code: -400`.
    private func fetchAppSearch(keyword: String, type: SearchType, page: Int, completion: @escaping ([Video]) -> Void) {
        let searchType = (type == .video) ? "video" : "bili_user"
        let params: [String: String] = [
            "search_type": searchType,
            "keyword": keyword,
            "page": String(page),
            "page_size": "20",
            "build": "7540000",
            "mobi_app": "android",
            "platform": "android"
        ]
        request("https://api.bilibili.com/x/v2/search", params: params, useAppUA: true, useAppSign: true) { [weak self] data, _, _ in
            guard let self = self else { return }
            let videos = self.parseAppSearch(data, type: type)
            DispatchQueue.main.async { completion(videos) }
        }
    }

    /// Server-side duration buckets to fetch for a given minimum duration.
    /// Bilibili buckets: 0=全部, 1=<10min, 2=10-30min, 3=30-60min, 4=>60min.
    /// Returns all buckets at or above the threshold's lower bound.
    private static func durationBuckets(for minSec: Int?) -> [Int] {
        guard let s = minSec else { return [0] }
        if s >= 3600 { return [4] }
        if s >= 1800 { return [3, 4] }
        if s >= 600 { return [2, 3, 4] }
        return [0]
    }

    private static func filterByMinDuration(_ videos: [Video], _ minSec: Int?) -> [Video] {
        guard let s = minSec else { return videos }
        return videos.filter { $0.duration >= s }
    }

    /// Fetch one or more duration buckets. Multi-bucket fetches run in parallel
    /// and merge, preserving bucket order.
    private func fetchSearchBuckets(_ buckets: [Int], params: [String: String], type: SearchType, completion: @escaping ([Video]) -> Void) {
        let url = "https://api.bilibili.com/x/web-interface/search/type"
        if buckets.count == 1 {
            var p = params
            p["duration"] = String(buckets[0])
            fetchSearchPage(url: url, params: p, type: type, completion: completion)
            return
        }
        var columnResults = Array(repeating: [Video](), count: buckets.count)
        let group = DispatchGroup()
        for (index, bucket) in buckets.enumerated() {
            var p = params
            p["duration"] = String(bucket)
            group.enter()
            fetchSearchPage(url: url, params: p, type: type) { videos in
                columnResults[index] = videos
                group.leave()
            }
        }
        group.notify(queue: .main) {
            var seen = Set<String>()
            var merged: [Video] = []
            for column in columnResults {
                for v in column where !seen.contains(v.id) {
                    seen.insert(v.id)
                    merged.append(v)
                }
            }
            completion(merged)
        }
    }

    /// Fetch a single search page. If the body isn't JSON it means Bilibili served
    /// a risk-control HTML page (missing/expired buvid cookies) — refresh the
    /// visitor IDs and retry once, so search self-heals instead of showing an
    /// empty "没有匹配内容".
    private func fetchSearchPage(url: String, params: [String: String], type: SearchType, completion: @escaping ([Video]) -> Void) {
        // The search endpoint expects a Bilibili Referer; without one it is far
        // more likely to answer with the risk-control HTML page.
        let referer = "https://www.bilibili.com/"
        request(url, params: params, useWBI: false, referer: referer) { [weak self] data, _, _ in
            guard let self = self else { return }
            let videos = self.parseSearch(data, type: type)
            let isHTML = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } == nil
            if videos.isEmpty, isHTML {
                self.fetchBuvid3(retry: 1) {
                    self.request(url, params: params, useWBI: false, referer: referer) { d2, _, _ in
                        let retry = self.parseSearch(d2, type: type)
                        DispatchQueue.main.async { completion(retry) }
                    }
                }
            } else {
                DispatchQueue.main.async { completion(videos) }
            }
        }
    }

    // MARK: - Trending search keywords

    /// Fetch real-time hot search keywords from Bilibili.
    func fetchTrendingKeywords(limit: Int = 10, completion: @escaping ([String]) -> Void) {
        request("https://api.bilibili.com/x/web-interface/search/square", params: ["limit": String(limit)]) { data, _, _ in
            guard let json = self.parseJSON(data),
                  let d = json["data"] as? [String: Any],
                  let trending = d["trending"] as? [String: Any],
                  let list = trending["list"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let keywords = list.compactMap { $0["keyword"] as? String }.prefix(limit)
            DispatchQueue.main.async { completion(Array(keywords)) }
        }
    }

    // MARK: - Partition

    func fetchPartition(_ partition: Partition, page: Int = 1, completion: @escaping ([Video]) -> Void) {
        // Map partitions to Bilibili rid
        let ridMap: [Partition: Int] = [
            .anime: 1, .music: 3, .dance: 129, .game: 4, .knowledge: 36,
            .tech: 188, .life: 160, .guichu: 119, .fashion: 155,
            .auto: 202, .cinema: 181, .entertainment: 5
        ]
        let rid = ridMap[partition] ?? 1
        // ranking/region only returns ~11 videos (weekly top). To get a full,
        // paginated category feed we use the search API with the `tids` filter,
        // which returns hundreds of results.
        let params: [String: String] = [
            "search_type": "video",
            "keyword": partition.rawValue,
            "tids": String(rid),
            "page": String(page),
            "ps": "50",
            "order": "pubdate"
        ]
        request("https://api.bilibili.com/x/web-interface/search/type", params: params, useWBI: false) { [weak self] data, _, _ in
            let videos = self?.parseSearch(data, type: .video) ?? []
            DispatchQueue.main.async { completion(videos) }
        }
    }

    // MARK: - Following

    func fetchFollowing(completion: @escaping ([Video]) -> Void) {
        let params: [String: String] = ["type": "8", "ps": "20", "pn": "1"]
        request("https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all", params: params, useWBI: false) { [weak self] data, _, _ in
            let videos = self?.parseDynamic(data) ?? []
            DispatchQueue.main.async { completion(videos) }
        }
    }

    // MARK: - Video detail & stream

    func fetchVideoDetail(bvid: String, completion: @escaping (Video?) -> Void) {
        request("https://api.bilibili.com/x/web-interface/view", params: ["bvid": bvid]) { [weak self] data, _, _ in
            let video = self?.parseVideoDetail(data, bvid: bvid)
            DispatchQueue.main.async { completion(video) }
        }
    }

    /// DASH playback is OFF. On iOS the split DASH tracks can't be played
    /// directly — they must be muxed into an `AVMutableComposition`, and that
    /// muxing cost (CPU + extra track requests during prefetch) made the feed
    /// heavier to scroll without a perceptible startup gain. Short and long
    /// clips alike run on the progressive mp4 here.
    private let prefersDash = false

    /// A playable source for AVPlayer. Bilibili serves two kinds:
    /// - `.progressive`: a single mp4 with muxed audio+video. Simple, but its
    ///   moov atom is large (hundreds of KB), so playback takes a while to start.
    /// - `.dash`: separate video-only + audio-only fMP4 tracks whose init segments
    ///   are tiny (<1KB), so playback starts almost immediately. AVPlayer can't
    ///   play DASH directly, so the two tracks are muxed into an
    ///   `AVMutableComposition`.
    /// - `.asset`: a pre-muxed DASH composition. Muxing is the slow part of
    ///   starting playback, so we build it while the card is being prefetched and
    ///   hand the player a ready asset — the tap then starts instantly.
    enum PlayableStream {
        case progressive(URL)
        case dash(video: URL, audio: URL)
        case asset(AVAsset)
    }

    /// Resolve a playable stream for the given video. Progressive mp4 is the
    /// default path (see `prefersDash`); live and cinema have their own URLs.
    func resolveStream(for video: Video, completion: @escaping (PlayableStream?) -> Void) {
        // Return the cached stream immediately if available.
        if let cached = streamCache[video.id] {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        switch video.category {
        case "直播":
            requestLivePlayURL(roomId: video.id) { [weak self] url in
                let stream = url.map { PlayableStream.progressive($0) }
                if let stream = stream, let self = self { self.cacheStream(stream, for: video.id) }
                DispatchQueue.main.async { completion(stream) }
            }
        case "影视":
            requestCinemaPlayURL(seasonId: video.id) { [weak self] url in
                let stream = url.map { PlayableStream.progressive($0) }
                if let stream = stream, let self = self { self.cacheStream(stream, for: video.id) }
                DispatchQueue.main.async { completion(stream) }
            }
        default:
            resolveCid(for: video) { [weak self] cid in
                guard let self = self, cid > 0 else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                let loadProgressive = {
                    self.requestPlayURL(bvid: video.id, cid: cid) { url in
                        let stream = url.map { PlayableStream.progressive($0) }
                        if let stream = stream { self.cacheStream(stream, for: video.id) }
                        DispatchQueue.main.async { completion(stream) }
                    }
                }
                guard self.prefersDash else {
                    loadProgressive()
                    return
                }
                // DASH path (kept behind `prefersDash`): fetch the split tracks
                // and mux them into a ready composition during prefetch.
                self.requestDashPlayURL(bvid: video.id, cid: cid) { dash in
                    guard let dash = dash, case let .dash(vURL, aURL) = dash else {
                        loadProgressive()
                        return
                    }
                    self.buildDashComposition(videoURL: vURL, audioURL: aURL,
                                              knownSeconds: Double(max(video.duration, 0))) { asset in
                        let stream: PlayableStream = asset.map { .asset($0) } ?? dash
                        self.cacheStream(stream, for: video.id)
                        DispatchQueue.main.async { completion(stream) }
                    }
                }
            }
        }
    }

    /// Mux a DASH video-only + audio-only track pair into a single
    /// `AVMutableComposition` that AVPlayer can play directly. Returns nil when
    /// the tracks can't be loaded (the caller then falls back to `.dash`/progressive).
    func buildDashComposition(videoURL: URL, audioURL: URL, knownSeconds: Double,
                              completion: @escaping (AVAsset?) -> Void) {
        let options: [String: Any] = ["AVURLAssetHTTPHeaderFieldsKey": [
            "Referer": "https://www.bilibili.com/",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        ]]
        let videoAsset = AVURLAsset(url: videoURL, options: options)
        let audioAsset = AVURLAsset(url: audioURL, options: options)
        let finish: (AVAsset?) -> Void = { asset in
            DispatchQueue.main.async { completion(asset) }
        }
        Task {
            do {
                let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
                let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
                guard let vTrack = videoTracks.first, let aTrack = audioTracks.first else {
                    finish(nil)
                    return
                }
                let loaded = try await videoAsset.load(.duration)
                let seconds = (loaded.isNumeric && loaded.seconds > 0) ? loaded.seconds : knownSeconds
                guard seconds > 0 else {
                    finish(nil)
                    return
                }
                let range = CMTimeRange(start: .zero, duration: CMTime(seconds: seconds, preferredTimescale: 600))
                let composition = AVMutableComposition()
                guard let vComp = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                      let aComp = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    finish(nil)
                    return
                }
                try vComp.insertTimeRange(range, of: vTrack, at: .zero)
                try aComp.insertTimeRange(range, of: aTrack, at: .zero)
                finish(composition)
            } catch {
                print("[BiliBili] DASH mux failed: \(error)")
                finish(nil)
            }
        }
    }

    /// Resolve a progressive mp4 URL directly (used as a runtime fallback when a
    /// DASH composition fails to become playable). Does not touch the cache.
    func progressiveFallback(for video: Video, completion: @escaping (URL?) -> Void) {
        if video.category == "直播" || video.category == "影视" {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        resolveCid(for: video) { [weak self] cid in
            guard let self = self, cid > 0 else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.requestPlayURL(bvid: video.id, cid: cid, completion: completion)
        }
    }

    /// Resolve the cid for a video — feeds that already carry it skip the request.
    private func resolveCid(for video: Video, completion: @escaping (Int) -> Void) {
        if video.cid > 0 {
            DispatchQueue.main.async { completion(video.cid) }
            return
        }
        fetchVideoDetail(bvid: video.id) { detail in
            DispatchQueue.main.async { completion(detail?.cid ?? 0) }
        }
    }

    /// Fetch the DASH manifest and pick a muxable video + audio pair.
    private func requestDashPlayURL(bvid: String, cid: Int, completion: @escaping (PlayableStream?) -> Void) {
        let params: [String: String] = [
            "bvid": bvid,
            "cid": String(cid),
            "qn": "64",
            "fnval": "16",
            "fnver": "0",
            "fourk": "0"
        ]
        request("https://api.bilibili.com/x/player/playurl", params: params, referer: "https://www.bilibili.com/") { [weak self] data, _, _ in
            let stream = self?.parseDash(data)
            DispatchQueue.main.async { completion(stream) }
        }
    }

    /// Pick an H.264 (avc1) video track at up to 720p plus the richest audio
    /// track. H.264 is chosen over HEVC (hvc1) because AVPlayer's HEVC support
    /// outside HLS/DASH manifests is unreliable.
    private func parseDash(_ data: Data?) -> PlayableStream? {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let dash = d["dash"] as? [String: Any] else { return nil }
        let videos = (dash["video"] as? [[String: Any]]) ?? []
        let audios = (dash["audio"] as? [[String: Any]]) ?? []
        let avcPool = videos.filter { ($0["codecs"] as? String)?.hasPrefix("avc") == true }
        let pool = avcPool.isEmpty ? videos : avcPool
        let upTo720 = pool.filter { (($0["id"] as? Int) ?? 0) <= 64 }
        let chosenVideo = upTo720.max { (($0["id"] as? Int) ?? 0) < (($1["id"] as? Int) ?? 0) }
            ?? pool.min { (($0["id"] as? Int) ?? 0) < (($1["id"] as? Int) ?? 0) }
        let chosenAudio = audios.max { (($0["bandwidth"] as? Int) ?? 0) < (($1["bandwidth"] as? Int) ?? 0) }
        guard let vURL = streamURLString(from: chosenVideo),
              let aURL = streamURLString(from: chosenAudio) else { return nil }
        return .dash(video: vURL, audio: aURL)
    }

    private func streamURLString(from rep: [String: Any]?) -> URL? {
        guard let rep = rep else { return nil }
        if let s = rep["baseUrl"] as? String, let u = URL(string: s) { return u }
        if let backups = rep["backupUrl"] as? [String], let s = backups.first, let u = URL(string: s) { return u }
        return nil
    }

    // MARK: - Live stream URL

    /// Resolve a live room's playable stream URL (HLS m3u8, playable by AVPlayer).
    private func requestLivePlayURL(roomId: String, completion: @escaping (URL?) -> Void) {
        guard let rid = Int(roomId), rid > 0 else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        // protocol=1 → http_hls (ts/fmp4 m3u8); AVPlayer cannot play FLV.
        let params: [String: String] = [
            "room_id": String(rid),
            "protocol": "1",
            "format": "0,1,2",
            "codec": "0,1",
            "qn": "10000",
            "platform": "web",
            "ptype": "8"
        ]
        request("https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo", params: params) { [weak self] data, _, _ in
            let url = self?.parseLivePlayURL(data)
            DispatchQueue.main.async { completion(url) }
        }
    }

    /// Parse the live playurl response. Prefers HLS (ts/fmp4) which AVPlayer can
    /// play directly; falls back to FLV only if HLS is unavailable.
    func parseLivePlayURL(_ data: Data?) -> URL? {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let playurlInfo = d["playurl_info"] as? [String: Any],
              let playurl = playurlInfo["playurl"] as? [String: Any],
              let streams = playurl["stream"] as? [[String: Any]] else { return nil }

        // Collect all stream URLs grouped by format, prefer HLS.
        var hlsCandidates: [URL] = []
        var flvCandidates: [URL] = []

        for stream in streams {
            guard let formats = stream["format"] as? [[String: Any]] else { continue }
            for fmt in formats {
                let formatName = fmt["format_name"] as? String ?? ""
                guard let codecs = fmt["codec"] as? [[String: Any]] else { continue }
                for codec in codecs {
                    guard let baseURL = codec["base_url"] as? String,
                          let urlInfos = codec["url_info"] as? [[String: Any]],
                          let info = urlInfos.first,
                          let host = info["host"] as? String,
                          let extra = info["extra"] as? String else { continue }
                    let full = host + baseURL + extra
                    if let url = URL(string: full) {
                        if formatName == "ts" || formatName == "fmp4" {
                            hlsCandidates.append(url)
                        } else {
                            flvCandidates.append(url)
                        }
                    }
                }
            }
        }
        return hlsCandidates.first ?? flvCandidates.first
    }

    // MARK: - Cinema (PGC) stream URL

    /// Resolve a cinema season's first episode stream URL.
    private func requestCinemaPlayURL(seasonId: String, completion: @escaping (URL?) -> Void) {
        guard let sid = Int(seasonId), sid > 0 else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        // 1. Get season detail to find the first episode id
        request("https://api.bilibili.com/pgc/view/web/season", params: ["season_id": String(sid)]) { [weak self] data, _, _ in
            guard let json = self?.parseJSON(data),
                  let result = json["result"] as? [String: Any],
                  let episodes = result["episodes"] as? [[String: Any]],
                  let firstEp = episodes.first,
                  let epid = firstEp["id"] as? Int else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            // 2. Get playurl for the first episode
            let params: [String: String] = [
                "ep_id": String(epid),
                "qn": "80",
                "fnval": "0",
                "fnver": "0",
                "fourk": "1"
            ]
            self?.request("https://api.bilibili.com/pgc/player/web/playurl", params: params) { [weak self] data, _, _ in
                let url = self?.parseCinemaPlayURL(data)
                DispatchQueue.main.async { completion(url) }
            }
        }
    }

    /// Parse the PGC playurl response and return the first durl stream URL.
    func parseCinemaPlayURL(_ data: Data?) -> URL? {
        guard let json = parseJSON(data),
              let result = json["result"] as? [String: Any] else { return nil }
        if let durl = result["durl"] as? [[String: Any]],
           let first = durl.first,
           let url = first["url"] as? String {
            return URL(string: url)
        }
        return nil
    }

    /// Prefetch the playable stream for a video (called when a card appears on
    /// screen) so a later tap is instant. Concurrency is capped to avoid
    /// saturating the network.
    private var prefetchInFlight = 0
    private let maxPrefetchInFlight = 6
    func prefetchStreamURL(for video: Video) {
        guard streamCache[video.id] == nil else { return }
        guard prefetchInFlight < maxPrefetchInFlight else { return }
        prefetchInFlight += 1
        resolveStream(for: video) { [weak self] _ in
            // resolveStream caches the result itself; just release the slot.
            self?.prefetchInFlight -= 1
        }
    }

    private func requestPlayURL(bvid: String, cid: Int, completion: @escaping (URL?) -> Void) {
        // 720p first, then step down. Some videos simply don't offer 720p (or a
        // request gets rate-limited) — previously those came back empty and the
        // player never started.
        attemptPlayURL(bvid: bvid, cid: cid, qns: [64, 32, 16], completion: completion)
    }

    private func attemptPlayURL(bvid: String, cid: Int, qns: [Int], completion: @escaping (URL?) -> Void) {
        guard let qn = qns.first else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let params: [String: String] = [
            "bvid": bvid,
            "cid": String(cid),
            "qn": String(qn),
            "fnval": "0",
            "fnver": "0",
            "fourk": "0"
        ]
        request("https://api.bilibili.com/x/player/playurl", params: params, referer: "https://www.bilibili.com/") { [weak self] data, _, _ in
            if let url = self?.parsePlayURL(data) {
                DispatchQueue.main.async { completion(url) }
            } else {
                self?.attemptPlayURL(bvid: bvid, cid: cid, qns: Array(qns.dropFirst()), completion: completion)
            }
        }
    }

    // MARK: - Comments

    func fetchComments(bvid: String, completion: @escaping ([Comment], Int) -> Void) {
        // aid from bvid
        request("https://api.bilibili.com/x/web-interface/view", params: ["bvid": bvid]) { [weak self] data, _, _ in
            let aid = (self?.parseAid(data)) ?? 0
            guard aid > 0 else {
                DispatchQueue.main.async { completion([], 0) }
                return
            }
            let params: [String: String] = [
                "type": "1",
                "oid": String(aid),
                "ps": "20",
                "pn": "1"
            ]
            self?.request("https://api.bilibili.com/x/v2/reply", params: params) { data, _, _ in
                let comments = self?.parseComments(data) ?? []
                DispatchQueue.main.async { completion(comments, aid) }
            }
        }
    }

    // MARK: - Login (QR code)

    func generateQRCode(completion: @escaping (QRCodeResult?) -> Void) {
        request("https://passport.bilibili.com/x/passport-login/web/qrcode/generate") { data, _, _ in
            guard let json = self.parseJSON(data),
                  let d = json["data"] as? [String: Any],
                  let url = d["url"] as? String,
                  let key = d["qrcode_key"] as? String else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async { completion(QRCodeResult(url: url, key: key)) }
        }
    }

    func pollQRCode(key: String, completion: @escaping (QRCodePollResult) -> Void) {
        request("https://passport.bilibili.com/x/passport-login/web/qrcode/poll", params: ["qrcode_key": key]) { [weak self] data, response, _ in
            guard let json = self?.parseJSON(data),
                  let d = json["data"] as? [String: Any],
                  let code = d["code"] as? Int else {
                DispatchQueue.main.async { completion(.error) }
                return
            }
            switch code {
            case 0:
                // Success - extract cookies from Set-Cookie headers using HTTPCookie parser
                if let httpResponse = response as? HTTPURLResponse, let url = httpResponse.url {
                    var fields: [String: String] = [:]
                    for (key, value) in httpResponse.allHeaderFields {
                        if let k = key as? String, let v = value as? String {
                            fields[k] = v
                        }
                    }
                    for c in HTTPCookie.cookies(withResponseHeaderFields: fields, for: url) {
                        self?.cookies[c.name] = c.value
                    }
                }
                // Primary source: cookie_info.cookies array returned in the JSON body
                if let cookieInfo = d["cookie_info"] as? [String: Any],
                   let cookieList = cookieInfo["cookies"] as? [[String: Any]] {
                    for c in cookieList {
                        if let name = c["name"] as? String, let value = c["value"] as? String {
                            self?.cookies[name] = value
                        }
                    }
                }
                // Also parse cookie from url field if present (fallback)
                if let cookieUrl = d["url"] as? String, cookieUrl.contains("SESSDATA") {
                    self?.extractCookies(from: cookieUrl)
                }
                DispatchQueue.main.async { completion(.success) }
            case 86038:
                DispatchQueue.main.async { completion(.expired) }
            case 86090:
                DispatchQueue.main.async { completion(.scanned) }
            default:
                DispatchQueue.main.async { completion(.waiting) }
            }
        }
    }

    // MARK: - Login (SMS via web view)

    /// Store the session cookies harvested from the in-app web login (WKWebView).
    /// Bilibili's native SMS endpoints require a geetest captcha and reject
    /// non-browser requests (-400), so phone login runs on Bilibili's own page.
    func setLoginCookies(_ newCookies: [String: String]) {
        for (name, value) in newCookies where !value.isEmpty {
            cookies[name] = value
        }
    }

    // MARK: - UP主 space & relation

    /// Fetch a UP主's profile info (name, avatar, bio, follower/following counts).
    /// Uses /x/web-interface/card with Android app UA (no WBI, stable).
    func fetchUPSpaceInfo(mid: Int, completion: @escaping (UPSpaceInfo?) -> Void) {
        let params: [String: String] = ["mid": String(mid), "photo": "true"]
        request("https://api.bilibili.com/x/web-interface/card", params: params, useWBI: false, useAppUA: true, referer: "https://space.bilibili.com/\(mid)") { [weak self] data, _, _ in
            let info = self?.parseUPSpaceInfo(data)
            DispatchQueue.main.async { completion(info) }
        }
    }

    /// PGC seasons (影视 / 番剧) have no regular UP主, so the video list carries no
    /// avatar. Fetch the season's official owner ("up_info") from the season detail
    /// so the player can show an avatar instead of a blank circle.
    func fetchPgcSeasonOwner(seasonId: String, completion: @escaping (UPSpaceInfo?) -> Void) {
        guard let sid = Int(seasonId), sid > 0 else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let params: [String: String] = ["season_id": String(sid)]
        request("https://api.bilibili.com/pgc/view/web/season",
                params: params, useWBI: false, useAppUA: true,
                referer: "https://www.bilibili.com/bangumi/play/ss\(sid)") { [weak self] data, _, _ in
            let info = self?.parsePgcSeasonOwner(data)
            DispatchQueue.main.async { completion(info) }
        }
    }

    func parsePgcSeasonOwner(_ data: Data?) -> UPSpaceInfo? {
        guard let json = parseJSON(data),
              let r = json["result"] as? [String: Any],
              let up = r["up_info"] as? [String: Any],
              let avatar = up["avatar"] as? String, !avatar.isEmpty else { return nil }
        return UPSpaceInfo(
            mid: up["mid"] as? Int ?? 0,
            name: up["uname"] as? String ?? "",
            avatar: avatar,
            sign: "",
            level: 0,
            fans: up["follower"] as? Int ?? 0,
            following: 0,
            likes: 0,
            archiveCount: 0
        )
    }

    /// Fetch a UP主's video list (paginated).
    /// Primary: the app endpoint /x/v2/space/archive with app signing — it never
    /// triggers the web WBI risk-control (-352 / -799) that left most UP主 lists
    /// blank, returns code=0 reliably, and supports pn/ps pagination. Falls back
    /// to the web WBI endpoint when the app endpoint yields nothing.
    func fetchUPVideos(mid: Int, page: Int = 1, pageSize: Int = 30, completion: @escaping ([Video], Int) -> Void) {
        let params: [String: String] = [
            "vmid": String(mid),
            "ps": String(pageSize),
            "pn": String(page),
            "order": "pubdate",
            "mobi_app": "android",
            "platform": "android",
            "build": "7540000"
        ]
        request("https://app.bilibili.com/x/v2/space/archive",
                params: params, useAppUA: true, useAppSign: true) { [weak self] data, _, _ in
            let (videos, total) = self?.parseUPVideosApp(data, mid: mid) ?? ([], 0)
            if !videos.isEmpty {
                DispatchQueue.main.async { completion(videos, total) }
            } else {
                // App endpoint gave nothing — try the web WBI endpoint as backup.
                self?.fetchUPVideosWBI(mid: mid, page: page, pageSize: pageSize, retry: 4, completion: completion)
            }
        }
    }

    private func fetchUPVideosWBI(mid: Int, page: Int, pageSize: Int, retry: Int, completion: @escaping ([Video], Int) -> Void) {
        let params: [String: String] = [
            "mid": String(mid),
            "ps": String(pageSize),
            "pn": String(page),
            "order": "pubdate",
            "platform": "web",
            "web_location": "1550101",
            "order_avoided": "true"
        ]
        // On retries, force a fresh WBI key fetch in case the cached keys are stale.
        let forceRefresh = retry < 4
        request("https://api.bilibili.com/x/space/wbi/arc/search", params: params, useWBI: true, useAppUA: false, forceWBIRefresh: forceRefresh, referer: "https://space.bilibili.com/\(mid)/video") { [weak self] data, _, _ in
            let (videos, total, code, msg) = self?.parseUPVideosDebug(data) ?? ([], 0, -1, "parse failed")
            print("[BiliBili] fetchUPVideos mid=\(mid) page=\(page) retry=\(retry) code=\(code) msg=\(msg) count=\(videos.count)")
            if videos.isEmpty && retry > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    self?.fetchUPVideosWBI(mid: mid, page: page, pageSize: pageSize, retry: retry - 1, completion: completion)
                }
            } else {
                DispatchQueue.main.async { completion(videos, total) }
            }
        }
    }

    /// Check the follow relation between current user and a UP主.
    /// Returns true if currently following.
    func checkRelation(mid: Int, completion: @escaping (Bool) -> Void) {
        request("https://api.bilibili.com/x/relation", params: ["fid": String(mid)]) { data, _, _ in
            guard let json = self.parseJSON(data),
                  let d = json["data"] as? [String: Any],
                  let attribute = d["attribute"] as? Int else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            // attribute: 1 = following, 2 = followed back, 6 = mutual, 0 = none
            DispatchQueue.main.async { completion(attribute == 1 || attribute == 2 || attribute == 6) }
        }
    }

    /// Follow or unfollow a UP主. action: 1 = follow, 2 = unfollow.
    func modifyRelation(mid: Int, action: Int, completion: @escaping (Bool, String?) -> Void) {
        guard !csrf.isEmpty else {
            DispatchQueue.main.async { completion(false, "请先登录") }
            return
        }
        let form: [String: String] = [
            "fid": String(mid),
            "act": String(action),
            "re_src": "11",
            "csrf": csrf
        ]
        postRequest("https://api.bilibili.com/x/relation/modify", form: form) { data, _, _ in
            guard let json = self.parseJSON(data) else {
                DispatchQueue.main.async { completion(false, "网络错误") }
                return
            }
            let code = json["code"] as? Int ?? -1
            let msg = json["message"] as? String
            DispatchQueue.main.async { completion(code == 0, msg) }
        }
    }

    // MARK: - Video interactions (like / coin / favorite)

    /// Like or unlike a video. like: true = like, false = unlike.
    func likeVideo(bvid: String, like: Bool, completion: @escaping (Bool, String?) -> Void) {
        guard !csrf.isEmpty else {
            DispatchQueue.main.async { completion(false, "请先登录") }
            return
        }
        let form: [String: String] = [
            "bvid": bvid,
            "like": like ? "1" : "2",
            "csrf": csrf
        ]
        postRequest("https://api.bilibili.com/x/web-interface/archive/like", form: form) { data, _, _ in
            guard let json = self.parseJSON(data) else {
                DispatchQueue.main.async { completion(false, "网络错误") }
                return
            }
            let code = json["code"] as? Int ?? -1
            let msg = json["message"] as? String
            DispatchQueue.main.async { completion(code == 0, msg) }
        }
    }

    ///投币 to a video (1 or 2 coins).
    func coinVideo(bvid: String, multiply: Int = 1, completion: @escaping (Bool, String?) -> Void) {
        guard !csrf.isEmpty else {
            DispatchQueue.main.async { completion(false, "请先登录") }
            return
        }
        let form: [String: String] = [
            "bvid": bvid,
            "multiply": String(multiply),
            "select_like": "1",
            "csrf": csrf
        ]
        postRequest("https://api.bilibili.com/x/web-interface/coin/add", form: form) { data, _, _ in
            guard let json = self.parseJSON(data) else {
                DispatchQueue.main.async { completion(false, "网络错误") }
                return
            }
            let code = json["code"] as? Int ?? -1
            let msg = json["message"] as? String
            DispatchQueue.main.async { completion(code == 0, msg) }
        }
    }

    /// Favorite a video (adds to default favorites folder).
    func favoriteVideo(bvid: String, completion: @escaping (Bool, String?) -> Void) {
        guard !csrf.isEmpty else {
            DispatchQueue.main.async { completion(false, "请先登录") }
            return
        }
        // Add to default favorites folder (media_id of default folder)
        // First get the user's favorite folders, then add
        request("https://api.bilibili.com/x/v3/fav/folder/created/list-all", params: ["up_mid": cookies["DedeUserID"] ?? ""]) { [weak self] data, _, _ in
            guard let self = self,
                  let json = self.parseJSON(data),
                  let d = json["data"] as? [String: Any],
                  let list = d["list"] as? [[String: Any]],
                  let defaultFolder = list.first(where: { ($0["fav_state"] as? Int ?? 0) == 0 }) ?? list.first,
                  let mediaId = defaultFolder["id"] as? Int else {
                DispatchQueue.main.async { completion(false, "获取收藏夹失败") }
                return
            }
            let form: [String: String] = [
                "rid": bvid,
                "type": "2",
                "add_media_ids": String(mediaId),
                "csrf": self.csrf
            ]
            self.postRequest("https://api.bilibili.com/x/v3/fav/resource/deal", form: form) { data, _, _ in
                guard let json = self.parseJSON(data) else {
                    DispatchQueue.main.async { completion(false, "网络错误") }
                    return
                }
                let code = json["code"] as? Int ?? -1
                let msg = json["message"] as? String
                DispatchQueue.main.async { completion(code == 0, msg) }
            }
        }
    }

    /// Fetch total number of favorited videos across all the user's folders.
    func fetchFavoriteCount(completion: @escaping (Int) -> Void) {
        let mid = cookies["DedeUserID"] ?? ""
        guard !mid.isEmpty else {
            DispatchQueue.main.async { completion(0) }
            return
        }
        request("https://api.bilibili.com/x/v3/fav/folder/created/list-all", params: ["up_mid": mid]) { data, _, _ in
            guard let json = self.parseJSON(data),
                  let d = json["data"] as? [String: Any],
                  let list = d["list"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion(0) }
                return
            }
            let total = list.reduce(0) { $0 + ($1["media_count"] as? Int ?? 0) }
            DispatchQueue.main.async { completion(total) }
        }
    }

    /// Fetch the user's favorite folders (id + name + media count).
    func fetchFavoriteFolders(completion: @escaping ([FavoriteFolder]) -> Void) {
        let mid = cookies["DedeUserID"] ?? ""
        guard !mid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        request("https://api.bilibili.com/x/v3/fav/folder/created/list-all", params: ["up_mid": mid]) { data, _, _ in
            guard let json = self.parseJSON(data),
                  let d = json["data"] as? [String: Any],
                  let list = d["list"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let folders = list.compactMap { item -> FavoriteFolder? in
                guard let id = item["id"] as? Int,
                      let title = item["title"] as? String else { return nil }
                return FavoriteFolder(id: id, title: title, count: item["media_count"] as? Int ?? 0)
            }
            DispatchQueue.main.async { completion(folders) }
        }
    }

    /// Fetch videos inside a favorite folder (paginated).
    func fetchFavoriteVideos(mediaId: Int, page: Int = 1, completion: @escaping ([Video], Int) -> Void) {
        let params: [String: String] = [
            "media_id": String(mediaId),
            "pn": String(page),
            "ps": "20",
            "platform": "web"
        ]
        request("https://api.bilibili.com/x/v3/fav/resource/list", params: params) { [weak self] data, _, _ in
            guard let self = self,
                  let json = self.parseJSON(data),
                  let d = json["data"] as? [String: Any],
                  let medias = d["medias"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion([], 0) }
                return
            }
            let total = d["total"] as? Int ?? medias.count
            let videos = medias.compactMap { item -> Video? in
                guard let bvid = item["bvid"] as? String,
                      let title = item["title"] as? String else { return nil }
                let upper = item["upper"] as? [String: Any]
                let cnt = item["cnt_info"] as? [String: Any]
                return Video(
                    id: bvid,
                    title: title,
                    cover: BiliAPI.coverURL(item["cover"] as? String ?? ""),
                    duration: item["duration"] as? Int ?? 0,
                    upName: upper?["name"] as? String ?? "",
                    upMid: upper?["mid"] as? Int ?? 0,
                    upAvatar: BiliAPI.coverURL(upper?["face"] as? String ?? ""),
                    views: cnt?["play"] as? Int ?? 0,
                    danmaku: cnt?["danmaku"] as? Int ?? 0,
                    publishTime: self.formatTime(item["pubtime"] as? Int ?? 0),
                    category: item["tname"] as? String ?? "",
                    tags: self.parseTags(item["tag"]),
                    desc: item["intro"] as? String ?? "",
                    likes: 0, coins: 0, favorites: 0, shares: 0,
                    cid: 0,
                    tid: self.parseTid(item["tid"])
                )
            }
            DispatchQueue.main.async { completion(videos, total) }
        }
    }

    /// Post a comment to a video. type=1 (video), oid=aid.
    func postComment(aid: Int, message: String, completion: @escaping (Bool, String?) -> Void) {
        guard !csrf.isEmpty else {
            DispatchQueue.main.async { completion(false, "请先登录") }
            return
        }
        let form: [String: String] = [
            "type": "1",
            "oid": String(aid),
            "message": message,
            "csrf": csrf
        ]
        postRequest("https://api.bilibili.com/x/v2/reply/add", form: form) { data, _, _ in
            guard let json = self.parseJSON(data) else {
                DispatchQueue.main.async { completion(false, "网络错误") }
                return
            }
            let code = json["code"] as? Int ?? -1
            let msg = json["message"] as? String
            DispatchQueue.main.async { completion(code == 0, msg) }
        }
    }

    private func saveSetCookies(_ header: String) {
        let parts = header.components(separatedBy: ",")
        for part in parts {
            let cookiePart = part.components(separatedBy: ";").first ?? part
            let kv = cookiePart.components(separatedBy: "=")
            if kv.count >= 2 {
                cookies[kv[0].trimmingCharacters(in: .whitespaces)] = kv[1]
            }
        }
    }

    private func extractCookies(from urlString: String) {
        guard let comps = URLComponents(string: urlString),
              let queryItems = comps.queryItems else { return }
        for item in queryItems {
            if let value = item.value, !value.isEmpty {
                cookies[item.name] = value
            }
        }
    }

    // MARK: - User info & history

    func fetchUserInfo(completion: @escaping (User?) -> Void) {
        request("https://api.bilibili.com/x/web-interface/nav") { [weak self] data, _, _ in
            guard let json = self?.parseJSON(data),
                  let d = json["data"] as? [String: Any],
                  let isLogin = d["isLogin"] as? Bool, isLogin else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let user = User(
                id: "\(d["mid"] as? Int ?? 0)",
                name: d["uname"] as? String ?? "用户",
                avatar: BiliAPI.coverURL(d["face"] as? String ?? ""),
                level: (d["level_info"] as? [String: Any])?["current_level"] as? Int ?? 0,
                isVip: ((d["vipStatus"] as? Int) ?? 0) == 1,
                coins: d["coins"] as? Int ?? 0
            )
            DispatchQueue.main.async { completion(user) }
        }
    }

    func fetchHistory(completion: @escaping ([HistoryItem]) -> Void) {
        let params: [String: String] = ["ps": "20", "pn": "1"]
        request("https://api.bilibili.com/x/v2/history", params: params) { [weak self] data, _, _ in
            let items = self?.parseHistory(data) ?? []
            DispatchQueue.main.async { completion(items) }
        }
    }
}

// MARK: - Response parsing

private extension BiliAPI {
    func parseRecommend(_ data: Data?) -> [Video] {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let items = d["item"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let id = item["bvid"] as? String,
                  let title = item["title"] as? String else { return nil }
            return Video(
                id: id,
                title: title,
                cover: BiliAPI.coverURL(item["pic"] as? String ?? ""),
                duration: item["duration"] as? Int ?? 0,
                upName: (item["owner"] as? [String: Any])?["name"] as? String ?? "",
                upMid: (item["owner"] as? [String: Any])?["mid"] as? Int ?? 0,
                upAvatar: BiliAPI.coverURL((item["owner"] as? [String: Any])?["face"] as? String ?? ""),
                views: item["play"] as? Int ?? 0,
                danmaku: item["danmaku"] as? Int ?? 0,
                publishTime: formatTime(item["pubdate"] as? Int ?? 0),
                category: item["tname"] as? String ?? "",
                tags: self.parseTags(item["tag"]),
                desc: "",
                likes: 0, coins: 0, favorites: 0, shares: 0,
                cid: item["cid"] as? Int ?? 0,
                tid: self.parseTid(item["tid"] ?? item["typeid"])
            )
        }
    }

    func parseVideoList(_ data: Data?) -> [Video] {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let list = d["list"] as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let id = item["bvid"] as? String,
                  let title = item["title"] as? String else { return nil }
            let stat = item["stat"] as? [String: Any]
            return Video(
                id: id,
                title: title,
                cover: BiliAPI.coverURL(item["pic"] as? String ?? ""),
                duration: item["duration"] as? Int ?? 0,
                upName: (item["owner"] as? [String: Any])?["name"] as? String ?? "",
                upMid: (item["owner"] as? [String: Any])?["mid"] as? Int ?? 0,
                upAvatar: BiliAPI.coverURL((item["owner"] as? [String: Any])?["face"] as? String ?? ""),
                views: stat?["view"] as? Int ?? 0,
                danmaku: stat?["danmaku"] as? Int ?? 0,
                publishTime: formatTime(item["pubdate"] as? Int ?? 0),
                category: item["tname"] as? String ?? "",
                tags: self.parseTags(item["tag"]),
                desc: item["desc"] as? String ?? "",
                likes: stat?["like"] as? Int ?? 0,
                coins: stat?["coin"] as? Int ?? 0,
                favorites: stat?["favorite"] as? Int ?? 0,
                shares: stat?["share"] as? Int ?? 0,
                cid: item["cid"] as? Int ?? 0,
                tid: self.parseTid(item["tid"])
            )
        }
    }

    /// Parse the App-signed `/x/v2/search` response. Results live under
    /// `data.item[]` and are typed by `linktype` (`video` / `app_user` / `game` …).
    /// Video items carry bvid/cid inside `share.video`, so no extra resolve is
    /// needed to play them.
    func parseAppSearch(_ data: Data?, type: SearchType) -> [Video] {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let items = d["item"] as? [[String: Any]] else { return [] }
        switch type {
        case .video:
            return items.compactMap { item in
                guard (item["linktype"] as? String) == "video" else { return nil }
                guard let shareVideo = (item["share"] as? [String: Any])?["video"] as? [String: Any],
                      let bvid = shareVideo["bvid"] as? String, !bvid.isEmpty else { return nil }
                return Video(
                    id: bvid,
                    title: item["title"] as? String ?? "",
                    cover: BiliAPI.coverURL(item["cover"] as? String ?? ""),
                    duration: parseDuration(item["duration"] as? String ?? "0"),
                    upName: item["author"] as? String ?? "",
                    upMid: item["mid"] as? Int ?? 0,
                    upAvatar: BiliAPI.coverURL(item["face"] as? String ?? ""),
                    views: item["play"] as? Int ?? 0,
                    danmaku: 0,
                    publishTime: formatTime(item["ptime"] as? Int ?? 0),
                    category: item["tname"] as? String ?? "",
                    tags: self.parseTags(item["tag"]),
                    desc: "",
                    likes: 0, coins: 0, favorites: 0, shares: 0,
                    cid: shareVideo["cid"] as? Int ?? 0,
                    tid: self.parseTid(item["tid"] ?? item["typeid"])
                )
            }
        case .user:
            return items.compactMap { item in
                let linktype = item["linktype"] as? String ?? ""
                guard linktype.contains("user") else { return nil }
                // App user cards put the mid in `param` (a string).
                guard let mid = Int(item["param"] as? String ?? ""), mid > 0 else { return nil }
                let face = item["cover"] as? String
                    ?? ((item["share_plane"] as? [String: Any])?["author_face"] as? String) ?? ""
                return Video(
                    id: "\(mid)",
                    title: item["title"] as? String ?? "",
                    cover: BiliAPI.coverURL(face),
                    duration: 0,
                    upName: item["title"] as? String ?? "",
                    upMid: mid,
                    upAvatar: BiliAPI.coverURL(face),
                    views: item["fans"] as? Int ?? 0,
                    danmaku: 0,
                    publishTime: "",
                    category: "用户",
                    desc: item["sign"] as? String ?? "",
                    likes: 0, coins: 0, favorites: 0, shares: 0
                )
            }
        }
    }

    func parseSearch(_ data: Data?, type: SearchType) -> [Video] {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let result = d["result"] as? [[String: Any]] else { return [] }
        switch type {
        case .user:
            return result.compactMap { item in
                guard let uname = item["uname"] as? String else { return nil }
                let mid = item["mid"] as? Int ?? 0
                return Video(
                    id: "\(mid)",
                    title: uname,
                    cover: BiliAPI.coverURL(item["upic"] as? String ?? ""),
                    duration: 0,
                    upName: uname,
                    upMid: mid,
                    upAvatar: BiliAPI.coverURL(item["upic"] as? String ?? ""),
                    views: item["fans"] as? Int ?? 0,
                    danmaku: 0,
                    publishTime: "",
                    category: "用户",
                    desc: item["usign"] as? String ?? "",
                    likes: 0, coins: 0, favorites: 0, shares: 0
                )
            }
        case .video:
            return result.compactMap { item in
                guard let id = item["bvid"] as? String,
                      let title = item["title"] as? String else { return nil }
                let cleanTitle = title.replacingOccurrences(of: "<em class=\"keyword\">", with: "").replacingOccurrences(of: "</em>", with: "")
                return Video(
                    id: id,
                    title: cleanTitle,
                    cover: BiliAPI.coverURL(item["pic"] as? String ?? ""),
                    duration: parseDuration(item["duration"] as? String ?? "0"),
                    upName: item["author"] as? String ?? "",
                    upMid: item["mid"] as? Int ?? 0,
                    upAvatar: "",
                    views: item["play"] as? Int ?? 0,
                    danmaku: item["video_review"] as? Int ?? 0,
                    publishTime: formatTime(item["pubdate"] as? Int ?? 0),
                    category: item["typename"] as? String ?? "",
                    tags: self.parseTags(item["tag"]),
                    desc: item["description"] as? String ?? "",
                    likes: 0, coins: 0, favorites: 0, shares: 0,
                    cid: item["cid"] as? Int ?? 0,
                    tid: self.parseTid(item["typeid"])
                )
            }
        }
    }

    func parseRegion(_ data: Data?) -> [Video] {
        guard let json = parseJSON(data),
              let d = json["data"] else { return [] }
        // ranking/region returns data as a flat list; dynamic/region returned
        // data.archives. Support both for robustness.
        let archives: [[String: Any]]
        if let list = d as? [[String: Any]] {
            archives = list
        } else if let dict = d as? [String: Any],
                  let list = dict["archives"] as? [[String: Any]] {
            archives = list
        } else {
            return []
        }
        return archives.compactMap { item in
            guard let id = item["bvid"] as? String,
                  let title = item["title"] as? String else { return nil }
            let stat = item["stat"] as? [String: Any]
            return Video(
                id: id,
                title: title,
                cover: BiliAPI.coverURL(item["pic"] as? String ?? ""),
                duration: item["duration"] as? Int ?? 0,
                upName: (item["owner"] as? [String: Any])?["name"] as? String ?? (item["author"] as? String ?? ""),
                upMid: (item["owner"] as? [String: Any])?["mid"] as? Int ?? (item["mid"] as? Int ?? 0),
                upAvatar: BiliAPI.coverURL((item["owner"] as? [String: Any])?["face"] as? String ?? ""),
                views: stat?["view"] as? Int ?? (item["play"] as? Int ?? 0),
                danmaku: stat?["danmaku"] as? Int ?? (item["video_review"] as? Int ?? 0),
                publishTime: formatTime(item["pubdate"] as? Int ?? (item["created"] as? Int ?? 0)),
                category: item["tname"] as? String ?? "",
                tags: self.parseTags(item["tag"]),
                desc: item["desc"] as? String ?? (item["description"] as? String ?? ""),
                likes: stat?["like"] as? Int ?? 0,
                coins: stat?["coin"] as? Int ?? 0,
                favorites: stat?["favorite"] as? Int ?? (item["favorites"] as? Int ?? 0),
                shares: stat?["share"] as? Int ?? 0,
                cid: item["cid"] as? Int ?? 0
            )
        }
    }

    func parseDynamic(_ data: Data?) -> [Video] {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let items = d["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let modules = item["modules"] as? [String: Any],
                  let moduleAuthor = modules["module_author"] as? [String: Any],
                  let moduleDynamic = modules["module_dynamic"] as? [String: Any],
                  let major = moduleDynamic["major"] as? [String: Any],
                  let archive = major["archive"] as? [String: Any],
                  let bvid = archive["bvid"] as? String,
                  let title = archive["title"] as? String else { return nil }
            let stat = archive["stat"] as? [String: Any]
            return Video(
                id: bvid,
                title: title,
                cover: BiliAPI.coverURL(archive["cover"] as? String ?? ""),
                duration: archive["duration"] as? Int ?? 0,
                upName: moduleAuthor["name"] as? String ?? "",
                upMid: moduleAuthor["mid"] as? Int ?? 0,
                upAvatar: BiliAPI.coverURL(moduleAuthor["face"] as? String ?? ""),
                views: stat?["play"] as? Int ?? 0,
                danmaku: stat?["danmaku"] as? Int ?? 0,
                publishTime: "",
                category: archive["tname"] as? String ?? "",
                tags: self.parseTags(archive["tag"]),
                desc: archive["desc"] as? String ?? "",
                likes: 0, coins: 0, favorites: 0, shares: 0,
                cid: archive["cid"] as? Int ?? 0
            )
        }
    }

    func parseVideoDetail(_ data: Data?, bvid: String) -> Video? {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any] else { return nil }
        let stat = d["stat"] as? [String: Any]
        var video = Video(
            id: d["bvid"] as? String ?? bvid,
            title: d["title"] as? String ?? "",
            cover: BiliAPI.coverURL(d["pic"] as? String ?? ""),
            duration: d["duration"] as? Int ?? 0,
            upName: (d["owner"] as? [String: Any])?["name"] as? String ?? "",
            upMid: (d["owner"] as? [String: Any])?["mid"] as? Int ?? 0,
            upAvatar: BiliAPI.coverURL((d["owner"] as? [String: Any])?["face"] as? String ?? ""),
            views: stat?["view"] as? Int ?? 0,
            danmaku: stat?["danmaku"] as? Int ?? 0,
            publishTime: formatTime(d["pubdate"] as? Int ?? 0),
            category: d["tname"] as? String ?? "",
            tags: self.parseTags(d["tag"]),
            desc: d["desc"] as? String ?? "",
            likes: stat?["like"] as? Int ?? 0,
            coins: stat?["coin"] as? Int ?? 0,
            favorites: stat?["favorite"] as? Int ?? 0,
            shares: stat?["share"] as? Int ?? 0,
            cid: d["cid"] as? Int ?? 0
        )
        video.aid = d["aid"] as? Int ?? 0
        return video
    }

    func parseUPSpaceInfo(_ data: Data?) -> UPSpaceInfo? {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let card = d["card"] as? [String: Any] else { return nil }
        let levelInfo = card["level_info"] as? [String: Any]
        return UPSpaceInfo(
            mid: (card["mid"] as? Int) ?? (Int(card["mid"] as? String ?? "0") ?? 0),
            name: card["name"] as? String ?? "",
            avatar: BiliAPI.coverURL(card["face"] as? String ?? ""),
            sign: card["sign"] as? String ?? "",
            level: levelInfo?["current_level"] as? Int ?? 0,
            fans: (card["fans"] as? Int) ?? (d["follower"] as? Int) ?? 0,
            following: card["friend"] as? Int ?? 0,
            likes: d["like_num"] as? Int ?? 0,
            archiveCount: d["archive_count"] as? Int ?? 0
        )
    }

    func parseUPVideosDebug(_ data: Data?) -> ([Video], Int, Int, String) {
        guard let json = parseJSON(data) else { return ([], 0, -1, "parseJSON nil") }
        let code = json["code"] as? Int ?? -1
        let msg = json["message"] as? String ?? ""
        guard let d = json["data"] as? [String: Any],
              let list = d["list"] as? [String: Any],
              let vlist = list["vlist"] as? [[String: Any]] else {
            return ([], 0, code, msg)
        }
        let total = (d["page"] as? [String: Any])?["count"] as? Int ?? vlist.count
        let videos = vlist.compactMap { item -> Video? in
            guard let bvid = item["bvid"] as? String,
                  let title = item["title"] as? String else { return nil }
            return Video(
                id: bvid,
                title: title,
                cover: BiliAPI.coverURL(item["pic"] as? String ?? ""),
                duration: parseDuration(item["length"] as? String ?? "0"),
                upName: item["author"] as? String ?? "",
                upMid: item["mid"] as? Int ?? 0,
                upAvatar: "",
                views: item["play"] as? Int ?? 0,
                danmaku: item["video_review"] as? Int ?? 0,
                publishTime: formatTime(item["created"] as? Int ?? 0),
                category: item["tname"] as? String ?? "",
                tags: self.parseTags(item["tag"]),
                desc: item["description"] as? String ?? "",
                likes: 0, coins: 0, favorites: 0, shares: 0,
                cid: item["cid"] as? Int ?? 0
            )
        }
        return (videos, total > 0 ? total : videos.count, code, msg)
    }

    func parseUPVideos(_ data: Data?) -> ([Video], Int) {
        let (v, t, _, _) = parseUPVideosDebug(data)
        return (v, t)
    }

    /// Parse the app endpoint /x/v2/space/archive response (data.item[]).
    /// Fields: title / cover / duration(sec) / play / danmaku / ctime / author / bvid / first_cid.
    func parseUPVideosApp(_ data: Data?, mid: Int) -> ([Video], Int) {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let items = d["item"] as? [[String: Any]] else { return ([], 0) }
        let total = d["count"] as? Int ?? items.count
        let videos = items.compactMap { item -> Video? in
            guard let bvid = item["bvid"] as? String,
                  let title = item["title"] as? String else { return nil }
            let dur = item["duration"] as? Int ?? 0
            return Video(
                id: bvid,
                title: title,
                cover: BiliAPI.coverURL(item["cover"] as? String ?? ""),
                duration: dur > 0 ? dur : parseDuration(item["length"] as? String ?? "0"),
                upName: item["author"] as? String ?? "",
                upMid: mid,
                upAvatar: "",
                views: item["play"] as? Int ?? 0,
                danmaku: item["danmaku"] as? Int ?? 0,
                publishTime: formatTime(item["ctime"] as? Int ?? 0),
                category: item["tname"] as? String ?? "",
                tags: self.parseTags(item["tag"]),
                desc: "",
                likes: 0, coins: 0, favorites: 0, shares: 0,
                cid: item["first_cid"] as? Int ?? 0
            )
        }
        return (videos, total > 0 ? total : videos.count)
    }

    func parsePlayURL(_ data: Data?) -> URL? {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any] else { return nil }
        // Only use `durl`: a progressive mp4 with muxed audio+video, which is what
        // AVPlayer can actually play. The DASH fallback used to return a
        // video-only fMP4 base URL that AVPlayer cannot play (or plays with no
        // audio / stalls), which is what made some videos "unplayable".
        if let durl = d["durl"] as? [[String: Any]],
           let first = durl.first,
           let url = first["url"] as? String {
            return URL(string: url)
        }
        return nil
    }

    func parseAid(_ data: Data?) -> Int {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any] else { return 0 }
        return d["aid"] as? Int ?? 0
    }

    /// 把 B 站 tag 字符串（逗号/空格/竖线分隔）拆成数组，便于过滤。
    func parseTags(_ value: Any?) -> [String] {
        guard let text = value as? String, !text.isEmpty else { return [] }
        let separators = CharacterSet(charactersIn: ",，/| ")
        return text.components(separatedBy: separators).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Bilibili returns the partition id sometimes as an Int (`tid`) and
    /// sometimes as a numeric String (`typeid`). Normalise both to Int.
    func parseTid(_ value: Any?) -> Int {
        if let n = value as? Int { return n }
        if let s = value as? String { return Int(s) ?? 0 }
        if let n = value as? NSNumber { return n.intValue }
        return 0
    }

    func parseComments(_ data: Data?) -> [Comment] {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let replies = d["replies"] as? [[String: Any]] else { return [] }
        return replies.compactMap { reply in
            guard let content = reply["content"] as? [String: Any],
                  let msg = content["message"] as? String,
                  let member = reply["member"] as? [String: Any],
                  let uname = member["uname"] as? String else { return nil }
            return Comment(
                user: uname,
                avatar: BiliAPI.coverURL(member["avatar"] as? String ?? ""),
                content: msg,
                likes: reply["like"] as? Int ?? 0,
                time: formatTime(reply["ctime"] as? Int ?? 0)
            )
        }
    }

    func parseHistory(_ data: Data?) -> [HistoryItem] {
        guard let json = parseJSON(data),
              let list = json["data"] as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let history = item["history"] as? [String: Any],
                  let bvid = history["bvid"] as? String,
                  let title = history["title"] as? String else { return nil }
            return HistoryItem(
                videoId: bvid,
                title: title,
                cover: BiliAPI.coverURL(history["cover"] as? String ?? ""),
                upName: (item["author_name"] as? String) ?? "",
                duration: 0,
                progress: 0,
                watchedAt: Date(timeIntervalSince1970: TimeInterval(history["viewed_at"] as? Int ?? 0))
            )
        }
    }

    func parseLive(_ data: Data?) -> [Video] {
        guard let json = parseJSON(data), let d = json["data"] else { return [] }

        var rooms: [[String: Any]] = []

        // 1. Flat list — `room/v1/room/get_user_recommend` returns a plain array.
        if let flat = d as? [[String: Any]] {
            rooms.append(contentsOf: flat)
        } else if let dict = d as? [String: Any] {
            // 2. Recommend rooms (top of the live home page)
            if let rrl = dict["recommend_room_list"] as? [[String: Any]] {
                rooms.append(contentsOf: rrl)
            }
            // 3. Modular room lists (area-based groupings)
            if let modules = dict["room_list"] as? [[String: Any]] {
                for module in modules {
                    if let list = module["list"] as? [[String: Any]] {
                        rooms.append(contentsOf: list)
                    }
                }
            }
        }

        return rooms.compactMap { item in
            guard let title = item["title"] as? String,
                  let roomid = item["roomid"] as? Int, roomid > 0 else { return nil }
            return Video(
                id: "\(roomid)",
                title: title,
                cover: BiliAPI.coverURL(item["user_cover"] as? String
                                        ?? item["cover"] as? String
                                        ?? item["system_cover"] as? String
                                        ?? item["face"] as? String ?? ""),
                duration: 0,
                upName: item["uname"] as? String ?? "",
                upMid: item["uid"] as? Int ?? item["up_id"] as? Int ?? 0,
                upAvatar: BiliAPI.coverURL(item["face"] as? String ?? ""),
                views: item["online"] as? Int ?? 0,
                danmaku: 0,
                publishTime: "直播中",
                category: "直播",
                desc: item["area_v2_name"] as? String ?? item["areaName"] as? String ?? "",
                likes: 0, coins: 0, favorites: 0, shares: 0
            )
        }
    }

    func parseCinema(_ data: Data?) -> [Video] {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let list = d["list"] as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let title = item["title"] as? String,
                  let sid = item["season_id"] as? Int, sid > 0 else { return nil }
            let stat = item["stat"] as? [String: Any]
            return Video(
                id: "\(sid)",
                title: title,
                cover: BiliAPI.coverURL(item["cover"] as? String ?? item["ss_horizontal_cover"] as? String ?? ""),
                duration: 0,
                upName: "",
                upAvatar: "",
                views: stat?["views"] as? Int ?? stat?["follow"] as? Int ?? 0,
                danmaku: 0,
                publishTime: item["new_ep"] as? String ?? "",
                category: "影视",
                desc: item["desc"] as? String ?? "",
                likes: 0, coins: 0, favorites: 0, shares: 0
            )
        }
    }

    // MARK: - Time formatting

    func formatTime(_ timestamp: Int) -> String {
        guard timestamp > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval/60))分钟前" }
        if interval < 86400 { return "\(Int(interval/3600))小时前" }
        if interval < 604800 { return "\(Int(interval/86400))天前" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    func parseDuration(_ s: String) -> Int {
        let parts = s.split(separator: ":").map { Int($0) ?? 0 }
        if parts.count == 3 { return parts[0]*3600 + parts[1]*60 + parts[2] }
        if parts.count == 2 { return parts[0]*60 + parts[1] }
        return parts.first ?? 0
    }
}

// MARK: - Models

struct QRCodeResult {
    let url: String
    let key: String
}

enum QRCodePollResult {
    case success, waiting, scanned, expired, error
}

struct Comment: Identifiable, Hashable {
    let id: String = UUID().uuidString
    let user: String
    let avatar: String
    let content: String
    let likes: Int
    let time: String
}

/// A user's favorites folder
struct FavoriteFolder: Identifiable, Hashable {
    let id: Int
    let title: String
    let count: Int
}

/// Add cid to Video for playurl API
extension Video {
    private static var cidStore: [String: Int] = [:]
    var cid: Int {
        get { Video.cidStore[id] ?? 0 }
        set { Video.cidStore[id] = newValue }
    }
    init(id: String, title: String, cover: String, duration: Int, upName: String,
         upMid: Int, upAvatar: String, views: Int, danmaku: Int, publishTime: String,
         category: String, tags: [String] = [], desc: String, likes: Int, coins: Int,
         favorites: Int, shares: Int, cid: Int, tid: Int = 0) {
        self.init(id: id, title: title, cover: cover, duration: duration,
                  upName: upName, upMid: upMid, upAvatar: upAvatar, views: views, danmaku: danmaku,
                  publishTime: publishTime, category: category, tags: tags, desc: desc,
                  likes: likes, coins: coins, favorites: favorites, shares: shares, tid: tid)
        self.cid = cid
    }
}

// MARK: - Data md5 helper (for app-side signing)

extension Data {
    func md5() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        self.withUnsafeBytes { bytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(self.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
