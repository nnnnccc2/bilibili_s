//
//  CachedAsyncImage.swift
//  BiliBili
//
//  顺滑的远程图片加载器 — 替代 SwiftUI AsyncImage。
//  对齐 PiliPlus 体验：内存+磁盘缓存、降采样、缩略图、同 URL 去重、淡入。
//
//  为什么 AsyncImage 卡顿：
//  • 无缓存 → 每次滑回来都重新下载
//  • 下载完不解码 → 主线程临时解码 full-res → 滚动掉帧
//  • 不知道 B站 CDN 有 @<w>w.webp 缩略图
//

import SwiftUI
import UIKit
import ImageIO

// MARK: - 图片加载器（全局单例）

final class ImageLoader {
    static let shared = ImageLoader()

    /// 已解码的 UIImage → 内存缓存，ScrollView 滑回来秒显示
    private let memory = NSCache<NSString, UIImage>()

    /// 同一个 URL 可能被 4 张卡片同时请求 → 只发 1 次网络
    private var inflight: [String: [(UIImage?) -> Void]] = [:]
    private let lock = NSLock()

    /// 后台解码队列，避免阻塞主线程
    private let decodeQueue = DispatchQueue(
        label: "BiliBili.Image.decode",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private init() {
        memory.countLimit = 300
        memory.totalCostLimit = 80 * 1024 * 1024 // 80MB

        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024,
            diskPath: "BiliBili.Image"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        session = URLSession(configuration: config)
    }

    private let session: URLSession

    /// 加载一张图片，按 targetSize 降采样解码。
    /// completion 一定回到主线程。
    func load(url: URL, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let key = url.absoluteString as NSString

        // 1. 内存命中 → 立即返回
        if let cached = memory.object(forKey: key) {
            completion(cached)
            return
        }

        lock.lock()
        let pending = inflight[url.absoluteString]
        inflight[url.absoluteString] = nil // 取出当前 list
        var waiting: [(UIImage?) -> Void] = []
        if let pending = pending {
            // 已有同 URL 在飞 → 把新的 completion 加进去
            waiting = pending
        }
        waiting.append(completion)
        inflight[url.absoluteString] = waiting
        lock.unlock()

        var req = URLRequest(url: url)
        req.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")

        session.dataTask(with: req) { [weak self] data, _, error in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let rawKey = url.absoluteString
            self.lock.lock()
            let callbacks = self.inflight[rawKey] ?? []
            self.inflight[rawKey] = nil
            self.lock.unlock()

            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    callbacks.forEach { $0(nil) }
                }
                return
            }

            // 后台降采样解码
            self.decodeQueue.async {
                let img = self.downsample(data: data, to: targetSize)
                if let img = img {
                    self.memory.setObject(img, forKey: key, cost: data.count)
                }
                DispatchQueue.main.async {
                    callbacks.forEach { $0(img) }
                }
            }
        }.resume()
    }

    /// 用 CGImageSource 按目标像素大小生成缩略图，避免 full-res 解码
    private func downsample(data: Data, to size: CGSize) -> UIImage? {
        let scale = max(UIScreen.main.scale, 2)
        let maxPixel = max(size.width, size.height) * scale
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixel, 40)
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data) // 最后 fallback
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - SwiftUI View

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    /// 目标显示尺寸（points），用来降采样解码，避免主线程 decode full-res
    let targetSize: CGSize
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var phase: Phase = .idle

    private enum Phase { case idle, loading, loaded, failed }

    var body: some View {
        ZStack {
            placeholder()
                .opacity(phase == .loaded ? 0 : 1)

            if let img = image {
                content(Image(uiImage: img))
                    .opacity(phase == .loaded ? 1 : 0)
            }
        }
        .clipped()
        // Single fade driven by phase — no `.id()` identity churn / per-load
        // transition, which caused dropped frames while scrolling fast.
        .animation(.easeOut(duration: 0.18), value: phase)
        .onAppear { load() }
        .onChange(of: url?.absoluteString) { _, _ in
            image = nil
            phase = .idle
            load()
        }
    }

    private func load() {
        guard let url = url else {
            phase = .failed
            return
        }
        phase = .loading
        ImageLoader.shared.load(url: url, targetSize: targetSize) { [weak image] result in
            // 如果 URL 中途变了，丢掉过时的结果
            guard url.absoluteString == self.url?.absoluteString else { return }
            if let result = result {
                self.image = result
                self.phase = .loaded
            } else {
                self.phase = .failed
            }
        }
    }
}

// MARK: - 更方便的 API（视频封面 / 头像）

extension BiliAPI {
    /// 把 bili cover URL 规范化成 https，同时加 CDN 缩略图后缀。
    ///   width=360 → 请求 @360w.webp (约 30-50KB vs 原始 100-300KB)
    static func coverThumb(_ raw: String, width: Int) -> String {
        let base = coverURL(raw)
        guard !base.isEmpty, !base.contains("@") else { return base }
        return "\(base)@\(width)w.webp"
    }
}
