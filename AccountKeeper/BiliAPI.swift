//
//  BiliAPI.swift
//  BiliBili
//
//  Bilibili data service (structured for real API, backed by curated mock data)
//

import Foundation

/// Home feed categories
enum HomeCategory: String, CaseIterable, Identifiable {
    case recommend = "推荐"
    case hot = "热门"
    case live = "直播"
    case cinema = "影视"
    var id: String { rawValue }
}

/// Search content types
enum SearchType: String, CaseIterable, Identifiable {
    case video = "视频"
    case bangumi = "番剧"
    case cinema = "影视"
    case user = "用户"
    case live = "直播"
    case article = "专栏"
    var id: String { rawValue }
}

/// Site partitions / categories
enum Partition: String, CaseIterable, Identifiable {
    case anime = "动画"
    case music = "音乐"
    case dance = "舞蹈"
    case game = "游戏"
    case knowledge = "知识"
    case tech = "数码"
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
        case .tech: return "laptopcomputer"
        case .life: return "cup.and.saucer"
        case .guichu: return "face.dashed"
        case .fashion: return "tshirt"
        case .news: return "newspaper"
        }
    }
}

/// Simulated Bilibili API. In production these methods would call the real
/// Bilibili REST endpoints (api.bilibili.com). The mock data is curated to
/// include videos that exercise every filter rule so the UI can demonstrate
/// the purification engine.
final class BiliAPI {

    static let shared = BiliAPI()

    private let coverBase = "https://picsum.photos/seed"

    // MARK: - Home feed

    func fetchHome(category: HomeCategory, completion: @escaping ([Video]) -> Void) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let all = MockVideos.allVideos
            let filtered: [Video]
            switch category {
            case .recommend: filtered = all
            case .hot: filtered = all.filter { $0.views > 500000 }
            case .live: filtered = all.filter { $0.category == "直播" }
            case .cinema: filtered = all.filter { $0.category == "影视" || $0.category == "纪录片" }
            }
            completion(filtered)
        }
    }

    // MARK: - Search

    func search(keyword: String, type: SearchType, completion: @escaping ([Video]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
                completion([])
                return
            }
            let kw = keyword.lowercased()
            let results = MockVideos.allVideos.filter { v in
                v.title.lowercased().contains(kw) ||
                v.upName.lowercased().contains(kw) ||
                v.category.lowercased().contains(kw) ||
                v.desc.lowercased().contains(kw)
            }
            completion(results)
        }
    }

    // MARK: - Partition

    func fetchPartition(_ partition: Partition, completion: @escaping ([Video]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let results = MockVideos.allVideos.filter { $0.category == partition.rawValue }
            completion(results.isEmpty ? Array(MockVideos.allVideos.prefix(8)) : results)
        }
    }

    // MARK: - Following / dynamic feed

    func fetchFollowing(completion: @escaping ([Video]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            completion(Array(MockVideos.allVideos.prefix(12)))
        }
    }

    // MARK: - Video detail / stream url (mock)

    func fetchVideoDetail(bvid: String, completion: @escaping (Video?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion(MockVideos.allVideos.first { $0.id == bvid })
        }
    }

    /// Returns a playable stream URL. In production this would call the Bilibili
    /// video stream API; here we use a publicly testable sample video.
    func streamURL(for video: Video) -> URL? {
        // Public domain test clip (Big Buck Bunny) for demonstration
        URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
    }

    // MARK: - Comments (mock)

    func fetchComments(bvid: String, completion: @escaping ([Comment]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion(MockVideos.sampleComments)
        }
    }
}

// MARK: - Comment model

struct Comment: Identifiable, Hashable {
    let id: String = UUID().uuidString
    let user: String
    let avatar: String
    let content: String
    let likes: Int
    let time: String
}
