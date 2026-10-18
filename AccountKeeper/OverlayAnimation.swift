//
//  OverlayAnimation.swift
//  BiliBili
//
//  Built-in page-transition animations and their tunable parameters.
//
//  Every candidate motion is compiled into the app; 动画实验室 (设置页) lets you
//  try each one on the real screens and drag its parameters until it feels
//  right, then keep it. Nothing here needs a rebuild to experiment with.
//

import Foundation
import SwiftUI

// MARK: - Curve

/// Easing curve used by the page transition.
enum OverlayAnimationCurve: String, CaseIterable, Identifiable, Codable {
    case easeOut
    case easeInOut
    case easeIn
    case linear
    case spring

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easeOut: return "缓出"
        case .easeInOut: return "缓入缓出"
        case .easeIn: return "缓入"
        case .linear: return "匀速"
        case .spring: return "弹簧"
        }
    }

    var detail: String {
        switch self {
        case .easeOut: return "起手即动、立即到位，响应最快，不拖尾"
        case .easeInOut: return "两端对称，最平滑，但起步略缓"
        case .easeIn: return "由慢到快，起步有迟滞感"
        case .linear: return "全程匀速，机械感强"
        case .spring: return "带回弹，弹性大小由「回弹」参数控制"
        }
    }
}

// MARK: - Parameters

/// The knobs a preset fills in (and that the sliders edit directly).
struct OverlayAnimationParameters: Hashable {
    var duration: Double
    var curve: OverlayAnimationCurve
    /// Spring damping fraction: 1 = no bounce, smaller = springier.
    var bounce: Double
    /// How far below its resting place the page starts, in points. 0 = no travel.
    var rise: Double
    /// Scale the page starts at. 1 = no scaling.
    var scaleFrom: Double
}

// MARK: - Presets

/// Ready-made page-transition styles. Picking one fills in the parameters.
enum OverlayAnimationStyle: String, CaseIterable, Identifiable, Codable {
    case firm
    case snappy
    case smooth
    case pop
    case leap
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firm: return "韧带"
        case .snappy: return "快速响应"
        case .smooth: return "丝滑"
        case .pop: return "弹出"
        case .leap: return "跃起"
        case .custom: return "自定义"
        }
    }

    var detail: String {
        switch self {
        case .firm: return "无位移无缩放，短而实，几乎察觉不到动画"
        case .snappy: return "最短的纯淡入，点下去就已经到位"
        case .smooth: return "对称缓入缓出，最顺滑但略慢"
        case .pop: return "原地由小弹大、同时前移一点，有「弹出来」的手感"
        case .leap: return "整页从屏幕下方弹簧上冲，动静最大"
        case .custom: return "手动调下面的参数"
        }
    }

    /// Parameters this preset applies. `nil` for 自定义.
    var parameters: OverlayAnimationParameters? {
        switch self {
        case .firm:
            return OverlayAnimationParameters(duration: 0.22, curve: .easeOut, bounce: 0.8, rise: 0, scaleFrom: 1)
        case .snappy:
            return OverlayAnimationParameters(duration: 0.14, curve: .easeOut, bounce: 0.8, rise: 0, scaleFrom: 1)
        case .smooth:
            return OverlayAnimationParameters(duration: 0.3, curve: .easeInOut, bounce: 0.8, rise: 0, scaleFrom: 1)
        case .pop:
            return OverlayAnimationParameters(duration: 0.3, curve: .spring, bounce: 0.62, rise: 14, scaleFrom: 0.96)
        case .leap:
            return OverlayAnimationParameters(duration: 0.42, curve: .spring, bounce: 0.7, rise: 220, scaleFrom: 1)
        case .custom:
            return nil
        }
    }
}

// MARK: - Settings

/// Persisted page-transition configuration. Defaults to the snappy "弹出" feel.
struct OverlayAnimationSettings: Codable, Hashable {
    var style: OverlayAnimationStyle = .pop
    var duration: Double = 0.3
    var curve: OverlayAnimationCurve = .spring
    var bounce: Double = 0.62
    var rise: Double = 14
    var scaleFrom: Double = 0.96

    // MARK: Animation builders

    /// Entering: the configured motion, verbatim.
    var enterAnimation: Animation {
        switch curve {
        case .easeOut: return .easeOut(duration: duration)
        case .easeInOut: return .easeInOut(duration: duration)
        case .easeIn: return .easeIn(duration: duration)
        case .linear: return .linear(duration: duration)
        case .spring: return .spring(response: duration, dampingFraction: bounce)
        }
    }

    /// Leaving: the same feel, released a little faster and without bounce, so
    /// dismissing never feels like it hangs around.
    var exitAnimation: Animation {
        if curve == .spring {
            return .spring(response: max(0.1, duration - 0.08), dampingFraction: min(1, bounce + 0.15))
        }
        return .easeOut(duration: max(0.08, duration - 0.04))
    }

    // MARK: Mutation helpers

    /// Fills in every parameter from a preset (the caller sets `style` itself).
    mutating func apply(_ parameters: OverlayAnimationParameters) {
        duration = parameters.duration
        curve = parameters.curve
        bounce = parameters.bounce
        rise = parameters.rise
        scaleFrom = parameters.scaleFrom
    }
}

// MARK: - Persistence

extension OverlayAnimationSettings {
    static let storageKey = "BiliBili.overlayAnimation"

    /// Reads the stored configuration. Used by `dismissImmersive`, which is a
    /// free function with no AppStore reference.
    static var persisted: OverlayAnimationSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(OverlayAnimationSettings.self, from: data)
        else { return OverlayAnimationSettings() }
        return decoded
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
    }
}
