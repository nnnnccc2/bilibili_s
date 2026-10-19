//
//  WBISigner.swift
//  BiliBili
//
//  Bilibili WBI signature implementation
//  Reference: https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/misc/sign/wbi.md
//

import Foundation
import CommonCrypto

final class WBISigner {
    static let shared = WBISigner()

    private let mixinKeyEncTab: [Int] = [
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
        27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
        37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
        22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
    ]

    private var imgKey: String = ""
    private var subKey: String = ""
    private var mixinKey: String = ""
    private var lastUpdate: Date = .distantPast

    /// Cookies to send when fetching WBI keys (buvid3 etc.).
    /// Set by BiliAPI on launch so the nav request isn't rejected.
    var cookieHeader: String = ""

    /// Dedicated ephemeral session for WBI key fetching — avoids URLSession.shared's
    /// long timeouts and connection reuse that can hang the nav request.
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        session = URLSession(configuration: config)
    }

    // MARK: - Public

    /// Fetch fresh img_key/sub_key from nav endpoint and compute mixin_key.
    /// Keys are cached for 1 hour. Set force=true to skip cache.
    func refreshKeysIfNeeded(force: Bool = false, completion: @escaping (Bool) -> Void) {
        if !force, !mixinKey.isEmpty, Date().timeIntervalSince(lastUpdate) < 3600 {
            completion(true)
            return
        }
        fetchKeys { [weak self] success in
            if success, let self = self {
                self.lastUpdate = Date()
            }
            completion(success)
        }
    }

    /// Sign query parameters. Returns the full query string with w_rid & wts appended.
    func sign(params: [String: String]) -> String {
        var p = params
        p["wts"] = String(Int(Date().timeIntervalSince1970))
        // Sort by key
        let sorted = p.sorted { $0.key < $1.key }
        // URL encode each pair (uppercase hex, %20 for space, strip !'()*)
        let query = sorted.map { key, value in
            let k = encode(key)
            let v = encode(stripSpecial(value))
            return "\(k)=\(v)"
        }.joined(separator: "&")
        let wbi = md5(query + mixinKey)
        return query + "&w_rid=" + wbi
    }

    // MARK: - Key fetching

    private func fetchKeys(completion: @escaping (Bool) -> Void) {
        fetchKeys(retry: 3, completion: completion)
    }

    private func fetchKeys(retry: Int, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://api.bilibili.com/x/web-interface/nav") else {
            completion(false)
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        req.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        if !cookieHeader.isEmpty {
            req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        session.dataTask(with: req) { [weak self] data, _, error in
            guard let self = self else { return }
            if error != nil {
                if retry > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        self.fetchKeys(retry: retry - 1, completion: completion)
                    }
                } else {
                    completion(false)
                }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = json["data"] as? [String: Any],
                  let wbi = dataDict["wbi_img"] as? [String: Any],
                  let imgUrl = wbi["img_url"] as? String,
                  let subUrl = wbi["sub_url"] as? String else {
                if retry > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        self.fetchKeys(retry: retry - 1, completion: completion)
                    }
                } else {
                    completion(false)
                }
                return
            }
            let img = WBISigner.extractKey(from: imgUrl)
            let sub = WBISigner.extractKey(from: subUrl)
            DispatchQueue.main.async {
                self.imgKey = img
                self.subKey = sub
                self.mixinKey = self.genMixinKey(img + sub)
                completion(true)
            }
        }.resume()
    }

    private static func extractKey(from url: String) -> String {
        guard let last = url.split(separator: "/").last else { return "" }
        return last.replacingOccurrences(of: ".png", with: "")
    }

    // MARK: - Mixin key

    private func genMixinKey(_ orig: String) -> String {
        let chars = Array(orig)
        var result = ""
        for idx in mixinKeyEncTab {
            if idx < chars.count {
                result.append(chars[idx])
            }
        }
        return String(result.prefix(32))
    }

    // MARK: - Encoding helpers

    /// Percent-encode with uppercase hex, space as %20, matching encodeURIComponent.
    private func encode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    /// Remove characters !'()* from values per WBI spec.
    private func stripSpecial(_ s: String) -> String {
        s.filter { !"!'()*".contains($0) }
    }

    // MARK: - MD5

    private func md5(_ s: String) -> String {
        let data = Data(s.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_MD5(ptr.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
// rebuild trigger Fri Oct 16 07:07:45 UTC 2026
