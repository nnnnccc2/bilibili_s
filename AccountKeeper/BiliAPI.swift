//
//  BiliAPI.swift
//  BiliBili
//
//  Real Bilibili API integration with WBI signing
//

import Foundation

// MARK: - Shared enums

enum HomeCategory: String, CaseIterable, Identifiable {
    case recommend = "推荐"
    case hot = "热门"
    case live = "直播"
    case cinema = "影视"
    var id: String { rawValue }
}

enum Partition: String, CaseIterable, Identifiable {
    case anime = "动画"
    case music = "音乐"
    case dance = "舞蹈"
    case game = "游戏"
    case knowledge = "知识"
    case tech = "科技"
    case life = "生活"
    case guichu = "鬼畜"
    case fashion = "时尚"
    case news = "资讯"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .anime: return "tv"
        case .music: return "music.note"
        case .dance: return "figure.dance"
        case .game: return "gamecontroller"
        case .knowledge: return "book"
        case .tech: return "cpu"
        case .life: return "cup.and.saucer"
        case .guichu: return "wand.and.stars"
        case .fashion: return "tshirt"
        case .news: return "newspaper"
        }
    }
}

enum SearchType: String, CaseIterable, Identifiable {
    case video = "视频"
    case bangumi = "番剧"
    case cinema = "影视"
    case user = "用户"
    case live = "直播"
    case article = "专栏"
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

    /// Visitor cookies (buvid3, buvid4, b_nut) fetched on launch; not persisted.
    private var visitorCookies: [String: String] = [:]

    /// Cache of resolved stream URLs keyed by bvid, to make playback near-instant on tap.
    private var streamURLCache: [String: URL] = [:]

    /// CSRF token (bili_jct) required for POST actions like follow/like/coin.
    var csrf: String { cookies["bili_jct"] ?? "" }

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        self.session = URLSession(configuration: config)
        loadCookies()
        fetchBuvid3()
    }

    // MARK: - Cookie helpers

    var cookieHeader: String {
        var all = visitorCookies
        for (k, v) in cookies { all[k] = v }
        return all.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    /// Fetch buvid3/buvid4 visitor IDs required by anti-bot checks (e.g. search API).
    private func fetchBuvid3() {
        guard let url = URL(string: "https://api.bilibili.com/x/frontend/finger/spi") else { return }
        var req = URLRequest(url: url)
        for (k, v) in baseHeaders { req.setValue(v, forHTTPHeaderField: k) }
        session.dataTask(with: req) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let d = json["data"] as? [String: Any] else { return }
            if let b3 = d["b_3"] as? String {
                self?.visitorCookies["buvid3"] = b3
            }
            if let b4 = d["b_4"] as? String {
                self?.visitorCookies["buvid4"] = b4
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

    func clearCookies() {
        cookies.removeAll()
        UserDefaults.standard.removeObject(forKey: "BiliBili.cookies")
    }

    // MARK: - Generic request

    private func request(_ urlString: String, params: [String: String] = [:], useWBI: Bool = false, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
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
                var comps = URLComponents(string: urlString)
                comps?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
                url = comps?.url
            }
            guard let finalURL = url else {
                completion(nil, nil, NSError(domain: "BiliAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                return
            }
            var req = URLRequest(url: finalURL)
            for (k, v) in self.baseHeaders { req.setValue(v, forHTTPHeaderField: k) }
            if !self.cookieHeader.isEmpty {
                req.setValue(self.cookieHeader, forHTTPHeaderField: "Cookie")
            }
            self.session.dataTask(with: req) { data, response, error in
                completion(data, response, error)
            }.resume()
        }

        if useWBI {
            WBISigner.shared.refreshKeysIfNeeded { _ in build(true) }
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

    /// Extract login cookies from a login response (Set-Cookie headers + url field).
    private func extractLoginCookies(from data: Data?, response: URLResponse?) {
        if let httpResponse = response as? HTTPURLResponse, let url = httpResponse.url {
            var fields: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                if let k = key as? String, let v = value as? String {
                    fields[k] = v
                }
            }
            for c in HTTPCookie.cookies(withResponseHeaderFields: fields, for: url) {
                cookies[c.name] = c.value
            }
        }
        if let json = parseJSON(data),
           let d = json["data"] as? [String: Any],
           let cookieUrl = d["url"] as? String, cookieUrl.contains("SESSDATA") {
            extractCookies(from: cookieUrl)
        }
    }

    /// Normalize a cover URL to an https:// URL that iOS can load under ATS.
    private static func coverURL(_ raw: String) -> String {
        if raw.hasPrefix("https://") { return raw }
        if raw.hasPrefix("http://") { return raw.replacingOccurrences(of: "http://", with: "https://") }
        if raw.hasPrefix("//") { return "https:" + raw }
        return raw
    }

    // MARK: - Home feed

    func fetchHome(category: HomeCategory, page: Int = 1, completion: @escaping ([Video]) -> Void) {
        switch category {
        case .recommend:
            // Recommendation feed (WBI signed) — fresh_idx increments for pagination
            let params: [String: String] = [
                "fresh_type": "4",
                "feed_version": "V8",
                "ps": "20",
                "fresh_idx": String(page)
            ]
            request("https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd", params: params, useWBI: true) { [weak self] data, _, _ in
                let videos = self?.parseRecommend(data) ?? []
                DispatchQueue.main.async { completion(videos) }
            }
        case .hot:
            let params: [String: String] = ["ps": "20", "pn": String(page)]
            request("https://api.bilibili.com/x/web-interface/popular", params: params) { [weak self] data, _, _ in
                let videos = self?.parseVideoList(data) ?? []
                DispatchQueue.main.async { completion(videos) }
            }
        case .live:
            // Live rooms
            request("https://api.live.bilibili.com/xlive/web-interface/v1/second/getList?platform=web&parent_area_id=0&area_id=0&page=\(page)") { [weak self] data, _, _ in
                let videos = self?.parseLive(data) ?? []
                DispatchQueue.main.async { completion(videos) }
            }
        case .cinema:
            let params: [String: String] = ["ps": "20", "pn": String(page), "type": "1"]
            request("https://api.bilibili.com/pgc/web/rank/list?season_type=1", params: params) { [weak self] data, _, _ in
                let videos = self?.parseCinema(data) ?? []
                DispatchQueue.main.async { completion(videos) }
            }
        }
    }

    // MARK: - Search

    func search(keyword: String, type: SearchType, page: Int = 1, completion: @escaping ([Video]) -> Void) {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion([])
            return
        }
        let searchType: String
        switch type {
        case .video: searchType = "video"
        case .bangumi: searchType = "media_bangumi"
        case .cinema: searchType = "media_ft"
        case .user: searchType = "bili_user"
        case .live: searchType = "live"
        case .article: searchType = "article"
        }
        let params: [String: String] = [
            "search_type": searchType,
            "keyword": keyword,
            "page": String(page)
        ]
        request("https://api.bilibili.com/x/web-interface/search/type", params: params, useWBI: true) { [weak self] data, _, _ in
            let videos = self?.parseSearch(data, type: type) ?? []
            DispatchQueue.main.async { completion(videos) }
        }
    }

    // MARK: - Partition

    func fetchPartition(_ partition: Partition, completion: @escaping ([Video]) -> Void) {
        // Map partitions to Bilibili rid
        let ridMap: [Partition: Int] = [
            .anime: 1, .music: 3, .dance: 129, .game: 4, .knowledge: 36,
            .tech: 188, .life: 160, .guichu: 119, .fashion: 155, .news: 202
        ]
        let rid = ridMap[partition] ?? 1
        let params: [String: String] = [
            "rid": String(rid),
            "ps": "20",
            "pn": "1"
        ]
        request("https://api.bilibili.com/x/web-interface/dynamic/region", params: params) { [weak self] data, _, _ in
            let videos = self?.parseRegion(data) ?? []
            DispatchQueue.main.async { completion(videos) }
        }
    }

    // MARK: - Following

    func fetchFollowing(completion: @escaping ([Video]) -> Void) {
        let params: [String: String] = ["type": "8", "ps": "20", "pn": "1"]
        request("https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all", params: params, useWBI: true) { [weak self] data, _, _ in
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

    /// Get a playable video stream URL using the Bilibili player API.
    /// Prefers a progressive mp4 (durl) with muxed audio+video so AVPlayer can play directly.
    /// Uses the cached cid (from feed APIs) when available to skip a redundant detail request.
    func streamURL(for video: Video, completion: @escaping (URL?) -> Void) {
        // Return cached URL immediately if available
        if let cached = streamURLCache[video.id] {
            DispatchQueue.main.async { completion(cached) }
            return
        }
        let cachedCid = video.cid
        if cachedCid > 0 {
            // Fast path: cid already known from feed, go straight to playurl
            requestPlayURL(bvid: video.id, cid: cachedCid) { [weak self] url in
                if let url = url { self?.streamURLCache[video.id] = url }
                completion(url)
            }
            return
        }
        // Slow path: fetch detail to get cid first
        fetchVideoDetail(bvid: video.id) { [weak self] detail in
            guard let cid = detail?.cid, cid > 0 else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self?.requestPlayURL(bvid: video.id, cid: cid) { url in
                if let url = url { self?.streamURLCache[video.id] = url }
                completion(url)
            }
        }
    }

    /// Prefetch the stream URL for a video (called when a card appears on screen).
    /// Only prefetches when cid is already known to avoid extra requests.
    func prefetchStreamURL(for video: Video) {
        guard streamURLCache[video.id] == nil, video.cid > 0 else { return }
        requestPlayURL(bvid: video.id, cid: video.cid) { [weak self] url in
            if let url = url { self?.streamURLCache[video.id] = url }
        }
    }

    private func requestPlayURL(bvid: String, cid: Int, completion: @escaping (URL?) -> Void) {
        let params: [String: String] = [
            "bvid": bvid,
            "cid": String(cid),
            "qn": "80",
            "fnval": "0",
            "fnver": "0",
            "fourk": "1"
        ]
        request("https://api.bilibili.com/x/player/playurl", params: params) { [weak self] data, _, _ in
            let url = self?.parsePlayURL(data)
            DispatchQueue.main.async { completion(url) }
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
                // Also parse cookie from url field if present
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

    // MARK: - Login (SMS verification code)

    /// Send an SMS verification code to the given phone number.
    /// - Parameters:
    ///   - phone: 11-digit Chinese mobile number
    ///   - completion: success flag + optional message
    func sendSMSCode(phone: String, completion: @escaping (Bool, String?) -> Void) {
        let form: [String: String] = [
            "tel": phone,
            "cid": "86",
            "source": "main_web",
            "keep": "1"
        ]
        postRequest("https://passport.bilibili.com/x/passport-login/web/sms/send", form: form) { [weak self] data, _, _ in
            guard let json = self?.parseJSON(data) else {
                DispatchQueue.main.async { completion(false, "网络错误") }
                return
            }
            let code = json["code"] as? Int ?? -1
            let msg = json["message"] as? String ?? "发送失败"
            if code == 0 {
                DispatchQueue.main.async { completion(true, nil) }
            } else {
                DispatchQueue.main.async { completion(false, msg) }
            }
        }
    }

    /// Login with phone number + SMS verification code.
    /// On success, cookies are extracted and stored; user info must be fetched separately.
    func loginWithSMS(phone: String, code: String, completion: @escaping (Bool, String?) -> Void) {
        let form: [String: String] = [
            "tel": phone,
            "cid": "86",
            "code": code,
            "source": "main_web",
            "keep": "1"
        ]
        postRequest("https://passport.bilibili.com/x/passport-login/web/sms/login", form: form) { [weak self] data, response, _ in
            guard let self = self, let json = self.parseJSON(data) else {
                DispatchQueue.main.async { completion(false, "网络错误") }
                return
            }
            let code = json["code"] as? Int ?? -1
            let msg = json["message"] as? String ?? "登录失败"
            if code == 0 {
                self.extractLoginCookies(from: data, response: response)
                DispatchQueue.main.async { completion(true, nil) }
            } else {
                DispatchQueue.main.async { completion(false, msg) }
            }
        }
    }

    // MARK: - UP主 space & relation

    /// Fetch a UP主's profile info (name, avatar, bio, follower/following counts).
    func fetchUPSpaceInfo(mid: Int, completion: @escaping (UPSpaceInfo?) -> Void) {
        let params: [String: String] = ["mid": String(mid)]
        request("https://api.bilibili.com/x/space/wbi/acc/info", params: params, useWBI: true) { [weak self] data, _, _ in
            let info = self?.parseUPSpaceInfo(data)
            DispatchQueue.main.async { completion(info) }
        }
    }

    /// Fetch a UP主's video list (paginated).
    func fetchUPVideos(mid: Int, page: Int = 1, pageSize: Int = 30, completion: @escaping ([Video], Int) -> Void) {
        let params: [String: String] = [
            "mid": String(mid),
            "ps": String(pageSize),
            "pn": String(page),
            "order": "pubdate",
            "platform": "web"
        ]
        request("https://api.bilibili.com/x/space/wbi/arc/search", params: params, useWBI: true) { [weak self] data, _, _ in
            let (videos, total) = self?.parseUPVideos(data) ?? ([], 0)
            DispatchQueue.main.async { completion(videos, total) }
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
                    category: "",
                    desc: item["intro"] as? String ?? "",
                    likes: 0, coins: 0, favorites: 0, shares: 0,
                    cid: 0
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
                category: "",
                desc: "",
                likes: 0, coins: 0, favorites: 0, shares: 0,
                cid: item["cid"] as? Int ?? 0
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
                category: "",
                desc: item["desc"] as? String ?? "",
                likes: stat?["like"] as? Int ?? 0,
                coins: stat?["coin"] as? Int ?? 0,
                favorites: stat?["favorite"] as? Int ?? 0,
                shares: stat?["share"] as? Int ?? 0,
                cid: item["cid"] as? Int ?? 0
            )
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
                return Video(
                    id: "\(item["mid"] as? Int ?? 0)",
                    title: uname,
                    cover: BiliAPI.coverURL(item["upic"] as? String ?? ""),
                    duration: 0,
                    upName: uname,
                    upAvatar: BiliAPI.coverURL(item["upic"] as? String ?? ""),
                    views: item["fans"] as? Int ?? 0,
                    danmaku: 0,
                    publishTime: "",
                    category: "用户",
                    desc: item["usign"] as? String ?? "",
                    likes: 0, coins: 0, favorites: 0, shares: 0
                )
            }
        default:
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
                    category: "",
                    desc: item["description"] as? String ?? "",
                    likes: 0, coins: 0, favorites: 0, shares: 0,
                    cid: item["cid"] as? Int ?? 0
                )
            }
        }
    }

    func parseRegion(_ data: Data?) -> [Video] {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let archives = d["archives"] as? [[String: Any]] else { return [] }
        return archives.compactMap { item in
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
                category: "",
                desc: "",
                likes: stat?["like"] as? Int ?? 0,
                coins: stat?["coin"] as? Int ?? 0,
                favorites: stat?["favorite"] as? Int ?? 0,
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
                category: "",
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
            category: "",
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
              let d = json["data"] as? [String: Any] else { return nil }
        let cards = d["cards"] as? [String: Any]
        let fans = cards?["fans"] as? Int ?? d["fans"] as? Int ?? 0
        let following = d["following"] as? Int ?? 0
        let likes = d["likes"] as? Int ?? 0
        let archiveCount = (cards?["archive_count"] as? Int) ?? (d["archive_count"] as? Int) ?? 0
        return UPSpaceInfo(
            mid: d["mid"] as? Int ?? 0,
            name: d["name"] as? String ?? "",
            avatar: BiliAPI.coverURL(d["face"] as? String ?? ""),
            sign: d["sign"] as? String ?? "",
            level: d["level"] as? Int ?? 0,
            fans: fans,
            following: following,
            likes: likes,
            archiveCount: archiveCount
        )
    }

    func parseUPVideos(_ data: Data?) -> ([Video], Int) {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let list = d["list"] as? [String: Any],
              let vlist = list["vlist"] as? [[String: Any]] else { return ([], 0) }
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
                category: "",
                desc: item["description"] as? String ?? "",
                likes: 0, coins: 0, favorites: 0, shares: 0,
                cid: item["cid"] as? Int ?? 0
            )
        }
        return (videos, total > 0 ? total : videos.count)
    }

    func parsePlayURL(_ data: Data?) -> URL? {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any] else { return nil }
        // Prefer durl: progressive mp4/flv with muxed audio+video (AVPlayer-friendly)
        if let durl = d["durl"] as? [[String: Any]],
           let first = durl.first,
           let url = first["url"] as? String {
            return URL(string: url)
        }
        // Fallback: DASH (video only, no separate audio muxing in AVPlayer)
        if let dash = d["dash"] as? [String: Any],
           let videoArr = dash["video"] as? [[String: Any]],
           let video = videoArr.first,
           let url = video["baseUrl"] as? String {
            return URL(string: url)
        }
        return nil
    }

    func parseAid(_ data: Data?) -> Int {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any] else { return 0 }
        return d["aid"] as? Int ?? 0
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
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let list = d["list"] as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let title = item["title"] as? String else { return nil }
            return Video(
                id: "\(item["roomid"] as? Int ?? 0)",
                title: title,
                cover: BiliAPI.coverURL(item["cover"] as? String ?? ""),
                duration: 0,
                upName: item["uname"] as? String ?? "",
                upAvatar: BiliAPI.coverURL(item["face"] as? String ?? ""),
                views: item["online"] as? Int ?? 0,
                danmaku: 0,
                publishTime: "直播中",
                category: "直播",
                desc: "",
                likes: 0, coins: 0, favorites: 0, shares: 0
            )
        }
    }

    func parseCinema(_ data: Data?) -> [Video] {
        guard let json = parseJSON(data),
              let d = json["data"] as? [String: Any],
              let list = d["list"] as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let title = item["title"] as? String else { return nil }
            return Video(
                id: "\(item["season_id"] as? Int ?? 0)",
                title: title,
                cover: BiliAPI.coverURL(item["cover"] as? String ?? ""),
                duration: 0,
                upName: "",
                upAvatar: "",
                views: (item["stat"] as? [String: Any])?["views"] as? Int ?? 0,
                danmaku: 0,
                publishTime: "",
                category: "影视",
                desc: item["evaluate"] as? String ?? "",
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
         upAvatar: String, views: Int, danmaku: Int, publishTime: String,
         category: String, desc: String, likes: Int, coins: Int,
         favorites: Int, shares: Int, cid: Int, upMid: Int = 0) {
        self.init(id: id, title: title, cover: cover, duration: duration,
                  upName: upName, upMid: upMid, upAvatar: upAvatar, views: views, danmaku: danmaku,
                  publishTime: publishTime, category: category, desc: desc,
                  likes: likes, coins: coins, favorites: favorites, shares: shares)
        self.cid = cid
    }
}
