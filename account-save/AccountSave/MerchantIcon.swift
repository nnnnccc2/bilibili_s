import SwiftUI

/// 依据名称生成稳定的图标底色与缩写。
enum MerchantIcon {
    static let palette: [Color] = [
        Color(red: 0.06, green: 0.70, blue: 0.53),
        Color(red: 0.89, green: 0.20, blue: 0.16),
        Color(red: 0.05, green: 0.60, blue: 0.55),
        Color(red: 0.15, green: 0.49, blue: 0.92),
        Color(red: 0.36, green: 0.40, blue: 0.45),
        Color(red: 0.58, green: 0.31, blue: 0.85)
    ]

    static func color(for name: String) -> Color {
        let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[seed % palette.count]
    }

    /// 图标上最多两行的缩写：拉丁名称取前 4 个字母，中文取前 2 个字。
    static func lines(for name: String) -> [String] {
        let characters = Array(name.filter { !$0.isWhitespace })
        guard let first = characters.first else { return ["?"] }

        let isLatin = characters.allSatisfy { $0.isASCII }
        let count = isLatin ? min(4, characters.count) : min(2, characters.count)
        guard count > 1 else { return [String(first)] }

        let picked = Array(characters.prefix(count))
        let half = (count + 1) / 2
        return [String(picked.prefix(half)), String(picked.suffix(count - half))]
    }
}

/// 账号 / 商家图标。
struct MerchantIconView: View {
    let name: String
    var size: CGFloat = 48

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            .fill(MerchantIcon.color(for: name))
            .frame(width: size, height: size)
            .overlay {
                VStack(spacing: 0) {
                    ForEach(Array(MerchantIcon.lines(for: name).enumerated()), id: \.offset) { _, line in
                        Text(line)
                    }
                }
                .font(.system(size: size * 0.25, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .padding(size * 0.1)
            }
    }
}
