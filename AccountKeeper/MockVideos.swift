//
//  MockVideos.swift
//  BiliBili
//
//  Curated mock video data demonstrating every filter rule
//

import Foundation

enum MockVideos {

    /// A curated dataset. The first several entries are deliberately crafted
    /// to trigger each filter rule so the purification engine is visible in action.
    static let allVideos: [Video] = [
        // --- These SHOULD be blocked by default settings ---
        Video(
            id: "BVclickbait1",
            title: "疯了！这操作直接封神，看完我人傻了！！！",
            cover: "https://picsum.photos/seed/click1/400/240",
            duration: 45,
            upName: "震惊部小编",
            upAvatar: "https://i.pravatar.cc/100?img=1",
            views: 1_200_000, danmaku: 3200,
            publishTime: "2小时前", category: "生活",
            desc: "震惊！点击进来看看吧",
            likes: 23000, coins: 5400, favorites: 8900, shares: 1200
        ),
        Video(
            id: "BVjptitle1",
            title: "【ゆっくり実況】恐ろしい話を聞いてみた",
            cover: "https://picsum.photos/seed/jp1/400/240",
            duration: 612,
            upName: "ゆっくり茶畑",
            upAvatar: "https://i.pravatar.cc/100?img=2",
            views: 430000, danmaku: 1200,
            publishTime: "5小时前", category: "游戏",
            desc: "日本語の動画です",
            likes: 8800, coins: 2100, favorites: 5600, shares: 320
        ),
        Video(
            id: "BVjpup1",
            title: "手把手教你做日式咖喱饭，超简单！",
            cover: "https://picsum.photos/seed/jpup1/400/240",
            duration: 840,
            upName: "田中さんの厨房",
            upAvatar: "https://i.pravatar.cc/100?img=3",
            views: 780000, danmaku: 2300,
            publishTime: "1天前", category: "生活",
            desc: "跟着田中先生学做日料",
            likes: 45000, coins: 12000, favorites: 34000, shares: 5600
        ),
        Video(
            id: "BVshort1",
            title: "30秒学会一个生活小妙招",
            cover: "https://picsum.photos/seed/short1/400/240",
            duration: 28,
            upName: "生活小窍门",
            upAvatar: "https://i.pravatar.cc/100?img=4",
            views: 2_100_000, danmaku: 8800,
            publishTime: "30分钟前", category: "生活",
            desc: "快速技巧分享",
            likes: 67000, coins: 3400, favorites: 21000, shares: 8900
        ),
        Video(
            id: "BVinsult1",
            title: "这种脑残设计到底谁想出来的",
            cover: "https://picsum.photos/seed/insult1/400/240",
            duration: 540,
            upName: "数码吐槽君",
            upAvatar: "https://i.pravatar.cc/100?img=5",
            views: 560000, danmaku: 4100,
            publishTime: "8小时前", category: "数码",
            desc: "吐槽一下这个脑残设计",
            likes: 12000, coins: 2300, favorites: 5400, shares: 780
        ),
        Video(
            id: "BVexplosion1",
            title: "炸了！全网都在传的视频，千万别看！",
            cover: "https://picsum.photos/seed/explode1/400/240",
            duration: 72,
            upName: "热点速递",
            upAvatar: "https://i.pravatar.cc/100?img=6",
            views: 3_400_000, danmaku: 12000,
            publishTime: "1小时前", category: "资讯",
            desc: "太炸了！",
            likes: 89000, coins: 4500, favorites: 12000, shares: 23000
        ),
        Video(
            id: "BVdiao1",
            title: "屌爆了！这波操作我给满分",
            cover: "https://picsum.photos/seed/diao1/400/240",
            duration: 96,
            upName: "极限挑战王",
            upAvatar: "https://i.pravatar.cc/100?img=7",
            views: 980000, danmaku: 5600,
            publishTime: "3小时前", category: "生活",
            desc: "屌爆了的操作",
            likes: 34000, coins: 1200, favorites: 8900, shares: 4500
        ),

        // --- These SHOULD pass through (clean content) ---
        Video(
            id: "BVclean1",
            title: "刘谦魔术揭秘：真正的大师是如何在众目睽睽下完成不可能的奇迹？",
            cover: "https://picsum.photos/seed/clean1/400/240",
            duration: 388,
            upName: "魔术师谦哥",
            upAvatar: "https://i.pravatar.cc/100?img=11",
            views: 1_820_000, danmaku: 43000,
            publishTime: "5小时前", category: "生活",
            desc: "深度解析刘谦的经典魔术手法",
            likes: 124000, coins: 23000, favorites: 67000, shares: 8900
        ),
        Video(
            id: "BVclean2",
            title: "【纪录片】重返大熊猫栖息地：秦岭秘境的生灵物语",
            cover: "https://picsum.photos/seed/clean2/400/240",
            duration: 2700,
            upName: "国家地理视界",
            upAvatar: "https://i.pravatar.cc/100?img=12",
            views: 3_100_000, danmaku: 72000,
            publishTime: "3天前", category: "纪录片",
            desc: "深入秦岭腹地，记录大熊猫的真实生活",
            likes: 230000, coins: 45000, favorites: 180000, shares: 34000
        ),
        Video(
            id: "BVclean3",
            title: "【深空纪录片】韦伯太空望远镜最新发现：130亿光年前的远古星系群",
            cover: "https://picsum.photos/seed/clean3/400/240",
            duration: 7320,
            upName: "中国国家天文台科普",
            upAvatar: "https://i.pravatar.cc/100?img=13",
            views: 1_250_000, danmaku: 41000,
            publishTime: "1天前", category: "知识",
            desc: "韦伯望远镜带来的宇宙新发现",
            likes: 98000, coins: 34000, favorites: 87000, shares: 12000
        ),
        Video(
            id: "BVclean4",
            title: "2026最新折叠屏旗舰深度评测：铰链与续航真的能当主力机吗？",
            cover: "https://picsum.photos/seed/clean4/400/240",
            duration: 945,
            upName: "笔吧评测室",
            upAvatar: "https://i.pravatar.cc/100?img=14",
            views: 890000, danmaku: 21000,
            publishTime: "昨天", category: "数码",
            desc: "全面评测2026年最新折叠屏手机",
            likes: 56000, coins: 12000, favorites: 43000, shares: 6700
        ),
        Video(
            id: "BVclean5",
            title: "【原神】2026海灯节版本前瞻特别节目实况与全新剧情动画解析",
            cover: "https://picsum.photos/seed/clean5/400/240",
            duration: 3840,
            upName: "原神官方团队",
            upAvatar: "https://i.pravatar.cc/100?img=15",
            views: 6_890_000, danmaku: 154000,
            publishTime: "6小时前", category: "游戏",
            desc: "海灯节版本内容全面解析",
            likes: 340000, coins: 78000, favorites: 230000, shares: 45000
        ),
        Video(
            id: "BVclean6",
            title: "家常菜系列：红烧肉的地道做法，入口即化肥而不腻",
            cover: "https://picsum.photos/seed/clean6/400/240",
            duration: 720,
            upName: "老饭骨",
            upAvatar: "https://i.pravatar.cc/100?img=16",
            views: 2_340_000, danmaku: 28000,
            publishTime: "2天前", category: "生活",
            desc: "大师傅教你做正宗红烧肉",
            likes: 156000, coins: 34000, favorites: 120000, shares: 23000
        ),
        Video(
            id: "BVclean7",
            title: "钢琴演奏《月光奏鸣曲》第三乐章，技术与情感的完美融合",
            cover: "https://picsum.photos/seed/clean7/400/240",
            duration: 660,
            upName: "古典音乐频道",
            upAvatar: "https://i.pravatar.cc/100?img=17",
            views: 456000, danmaku: 3400,
            publishTime: "4天前", category: "音乐",
            desc: "贝多芬月光奏鸣曲第三乐章演奏",
            likes: 23000, coins: 5600, favorites: 18000, shares: 1200
        ),
        Video(
            id: "BVclean8",
            title: "【4K修复】经典动画《千与千寻》名场面合集，每一帧都是壁纸",
            cover: "https://picsum.photos/seed/clean8/400/240",
            duration: 1440,
            upName: "动漫修复馆",
            upAvatar: "https://i.pravatar.cc/100?img=18",
            views: 5_600_000, danmaku: 89000,
            publishTime: "1周前", category: "动画",
            desc: "4K修复版千与千寻经典片段",
            likes: 280000, coins: 67000, favorites: 340000, shares: 56000
        ),
        Video(
            id: "BVclean9",
            title: "React 19 新特性深度解析：并发渲染与服务端组件实战",
            cover: "https://picsum.photos/seed/clean9/400/240",
            duration: 1860,
            upName: "前端技术宅",
            upAvatar: "https://i.pravatar.cc/100?img=19",
            views: 234000, danmaku: 5600,
            publishTime: "5天前", category: "知识",
            desc: "React 19 核心新特性详解",
            likes: 12000, coins: 3400, favorites: 28000, shares: 2300
        ),
        Video(
            id: "BVclean10",
            title: "【影视】《流浪地球3》正式预告解析，硬核科幻的极致呈现",
            cover: "https://picsum.photos/seed/clean10/400/240",
            duration: 480,
            upName: "电影解说君",
            upAvatar: "https://i.pravatar.cc/100?img=20",
            views: 4_500_000, danmaku: 67000,
            publishTime: "12小时前", category: "影视",
            desc: "流浪地球3预告片深度解析",
            likes: 234000, coins: 45000, favorites: 89000, shares: 34000
        ),
        Video(
            id: "BVclean11",
            title: "直播：城市夜景慢直播，陪你度过安静的夜晚",
            cover: "https://picsum.photos/seed/clean11/400/240",
            duration: 0,
            upName: "城市慢直播",
            upAvatar: "https://i.pravatar.cc/100?img=21",
            views: 89000, danmaku: 1200,
            publishTime: "直播中", category: "直播",
            desc: "城市夜景24小时慢直播",
            likes: 3400, coins: 200, favorites: 1200, shares: 450
        ),
        Video(
            id: "BVclean12",
            title: "健身教程：居家30分钟全身燃脂训练，无需器械",
            cover: "https://picsum.photos/seed/clean12/400/240",
            duration: 1800,
            upName: "健身教练老王",
            upAvatar: "https://i.pravatar.cc/100?img=22",
            views: 1_560_000, danmaku: 18000,
            publishTime: "6天前", category: "生活",
            desc: "居家燃脂训练教程",
            likes: 78000, coins: 12000, favorites: 95000, shares: 15000
        )
    ]

    static let sampleComments: [Comment] = [
        Comment(user: "爱学习的小明", avatar: "https://i.pravatar.cc/100?img=31",
                content: "讲解得非常清晰，学到了很多，感谢UP主！", likes: 234, time: "2小时前"),
        Comment(user: "科技爱好者", avatar: "https://i.pravatar.cc/100?img=32",
                content: "这个技术点正好是我最近在研究的，太及时了。", likes: 89, time: "3小时前"),
        Comment(user: "路过的观众", avatar: "https://i.pravatar.cc/100?img=33",
                content: "已经三连支持，期待更多干货内容。", likes: 56, time: "5小时前"),
        Comment(user: "深夜码字人", avatar: "https://i.pravatar.cc/100?img=34",
                content: "看完这个视频终于搞懂了，之前看了好多资料都没明白。", likes: 12, time: "1天前"),
        Comment(user: "萌新一枚", avatar: "https://i.pravatar.cc/100?img=35",
                content: "作为小白表示大部分看懂了，UP主讲得很通俗。", likes: 8, time: "1天前")
    ]

    /// Hot search keywords
    static let hotKeywords: [String] = [
        "原神海灯节", "折叠屏评测", "流浪地球3", "刘谦魔术",
        "韦伯望远镜", "红烧肉做法", "React 19", "千与千寻"
    ]
}
