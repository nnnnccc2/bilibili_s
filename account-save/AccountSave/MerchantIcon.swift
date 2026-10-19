import SwiftUI

/// 账号 / 商家图标：优先匹配品牌色与品牌标识，未知名称退化为色块 + 单行首字。
enum MerchantIcon {
    struct Brand {
        let keywords: [String]
        let color: Color
        let label: String
        var symbol: String?
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }

    /// 常用品牌：色块 + 名称（部分用图形标识）。关键词命中越长越优先。
    private static let brands: [Brand] = [
        Brand(keywords: ["中国移动", "移动"], color: rgb(0.00, 0.36, 0.66), label: "移动", symbol: "antenna.radiowaves.left.and.right"),
        Brand(keywords: ["中国联通", "联通"], color: rgb(0.80, 0.09, 0.06), label: "联通", symbol: "antenna.radiowaves.left.and.right"),
        Brand(keywords: ["中国电信", "电信"], color: rgb(0.00, 0.40, 0.72), label: "电信", symbol: "antenna.radiowaves.left.and.right"),
        Brand(keywords: ["huawei", "华为"], color: rgb(0.88, 0.06, 0.11), label: "华为"),
        Brand(keywords: ["荣耀"], color: rgb(0.10, 0.30, 0.72), label: "荣耀"),
        Brand(keywords: ["redmi", "小米"], color: rgb(1.00, 0.42, 0.00), label: "小米"),
        Brand(keywords: ["oppo"], color: rgb(0.10, 0.70, 0.32), label: "OPPO"),
        Brand(keywords: ["vivo"], color: rgb(0.16, 0.45, 0.95), label: "vivo"),
        Brand(keywords: ["網易", "网易"], color: rgb(0.87, 0.07, 0.10), label: "網易"),
        Brand(keywords: ["bilibili", "哔哩", "b站"], color: rgb(0.00, 0.65, 0.86), label: "哔哩"),
        Brand(keywords: ["豆包"], color: rgb(0.20, 0.44, 0.98), label: "豆包"),
        Brand(keywords: ["marscode", "mars"], color: rgb(0.10, 0.55, 0.55), label: "Mars"),
        Brand(keywords: ["trae"], color: rgb(0.06, 0.68, 0.50), label: "Trae"),
        Brand(keywords: ["腾讯"], color: rgb(0.10, 0.45, 0.92), label: "腾讯"),
        Brand(keywords: ["微信"], color: rgb(0.10, 0.75, 0.32), label: "微信"),
        Brand(keywords: ["支付宝"], color: rgb(0.10, 0.50, 0.95), label: "支付宝"),
        Brand(keywords: ["淘宝", "天猫", "阿里巴巴", "阿里"], color: rgb(1.00, 0.44, 0.00), label: "阿里"),
        Brand(keywords: ["京东"], color: rgb(0.87, 0.06, 0.09), label: "京东"),
        Brand(keywords: ["拼多多"], color: rgb(0.90, 0.10, 0.12), label: "拼多多"),
        Brand(keywords: ["美团"], color: rgb(1.00, 0.72, 0.00), label: "美团"),
        Brand(keywords: ["饿了么"], color: rgb(0.10, 0.55, 0.95), label: "饿了么"),
        Brand(keywords: ["字节", "抖音"], color: rgb(0.10, 0.10, 0.12), label: "抖音"),
        Brand(keywords: ["快手"], color: rgb(1.00, 0.30, 0.10), label: "快手"),
        Brand(keywords: ["百度"], color: rgb(0.16, 0.40, 0.95), label: "百度"),
        Brand(keywords: ["滴滴"], color: rgb(1.00, 0.56, 0.05), label: "滴滴"),
        Brand(keywords: ["苹果", "apple"], color: rgb(0.20, 0.20, 0.22), label: "Apple"),
        Brand(keywords: ["微软", "microsoft"], color: rgb(0.20, 0.60, 0.86), label: "微软"),
        Brand(keywords: ["快递", "物流", "顺丰"], color: rgb(0.12, 0.12, 0.14), label: "顺丰", symbol: "shippingbox.fill"),
        Brand(keywords: ["邮政"], color: rgb(0.00, 0.55, 0.32), label: "邮政", symbol: "envelope.fill"),
        Brand(keywords: ["银行", "信用卡"], color: rgb(0.78, 0.10, 0.12), label: "银行", symbol: "building.columns.fill")
    ]

    /// 未知名称的备选底色。
    private static let palette: [Color] = [
        rgb(0.06, 0.70, 0.53),
        rgb(0.89, 0.20, 0.16),
        rgb(0.05, 0.60, 0.55),
        rgb(0.15, 0.49, 0.92),
        rgb(0.36, 0.40, 0.45),
        rgb(0.58, 0.31, 0.85),
        rgb(0.95, 0.55, 0.10),
        rgb(0.24, 0.62, 0.86)
    ]

    static func brand(for name: String) -> Brand? {
        let lowered = name.lowercased()
        var matched: (brand: Brand, length: Int)?
        for brand in brands {
            for keyword in brand.keywords where lowered.contains(keyword.lowercased()) {
                if matched == nil || keyword.count > matched!.length {
                    matched = (brand, keyword.count)
                }
            }
        }
        return matched?.brand
    }

    static func fallbackColor(for name: String) -> Color {
        let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[seed % palette.count]
    }

    /// 单行缩写：中文取首字，拉丁取前两个字母。
    static func fallbackLabel(for name: String) -> String {
        let characters = Array(name.filter { !$0.isWhitespace })
        guard let first = characters.first else { return "?" }
        if first.isASCII {
            return String(characters.prefix(2)).uppercased()
        }
        return String(first)
    }
}

/// 账号 / 商家图标。
struct MerchantIconView: View {
    let name: String
    var size: CGFloat = 48

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay { content }
    }

    @ViewBuilder
    private var content: some View {
        if let symbol = brand?.symbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
        } else {
            Text(label)
                .font(.system(size: size * 0.30, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, size * 0.12)
        }
    }

    private var brand: MerchantIcon.Brand? {
        MerchantIcon.brand(for: name)
    }

    private var color: Color {
        brand?.color ?? MerchantIcon.fallbackColor(for: name)
    }

    private var label: String {
        brand?.label ?? MerchantIcon.fallbackLabel(for: name)
    }
}
