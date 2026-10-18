//
//  OverlayAnimation.swift
//  BiliBili
//
//  Built-in page-transition animations and their tunable parameters.
//
//  这里收录了 SwiftUI 平台自带的过渡（opacity / scale / move / slide / push /
//  blurReplace）以及常见的手工组合（弹出 / 上冲 / 下落 / 翻转 / 交叉溶解 …），
//  全部编译进 App。「动画实验室」可以逐个试、逐个调、即时生效，不用重构建。
//

import Foundation
import SwiftUI

// MARK: - Curve

/// Easing curves / springs SwiftUI ships out of the box.
enum OverlayAnimationCurve: String, CaseIterable, Identifiable, Codable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case smooth
    case snappy
    case bouncy
    case spring
    case interpolatingSpring
    case interactiveSpring

    var id: String { rawValue }

    /// 是否会用到「回弹」参数（决定实验室里是否显示该滑块）。
    var isSpringLike: Bool {
        switch self {
        case .spring, .interpolatingSpring, .interactiveSpring: return true
        default: return false
        }
    }

    var title: String {
        switch self {
        case .linear: return "匀速 linear"
        case .easeIn: return "缓入 easeIn"
        case .easeOut: return "缓出 easeOut"
        case .easeInOut: return "缓入缓出 easeInOut"
        case .smooth: return "平滑 smooth"
        case .snappy: return "轻快 snappy"
        case .bouncy: return "弹跳 bouncy"
        case .spring: return "弹簧 spring"
        case .interpolatingSpring: return "插值弹簧"
        case .interactiveSpring: return "交互弹簧"
        }
    }

    var detail: String {
        switch self {
        case .linear: return "全程匀速，机械感"
        case .easeIn: return "由慢到快，起步有迟滞"
        case .easeOut: return "起手即快、立刻到位，最跟手"
        case .easeInOut: return "两端对称，最平滑"
        case .smooth: return "平台预设：长距离移动时更顺"
        case .snappy: return "平台预设：短促轻快、干净利落"
        case .bouncy: return "平台预设：末端带弹跳"
        case .spring: return "经典弹簧，回弹由「回弹」滑块控制"
        case .interpolatingSpring: return "物理插值弹簧，回弹更明显"
        case .interactiveSpring: return "跟手交互用的快速弹簧"
        }
    }
}

// MARK: - Parameters

/// Every knob a preset fills in (and that the sliders edit directly).
struct OverlayAnimationParameters: Hashable {
    var duration: Double
    var curve: OverlayAnimationCurve
    /// 弹簧阻尼比：1 = 不回弹，越小越弹。
    var bounce: Double
    /// 水平起始位移（正值向右），pt。
    var travelX: Double
    /// 垂直起始位移（正值向下），pt。
    var travelY: Double
    /// 起始缩放。1 = 不缩放。
    var scaleFrom: Double
    /// 起始旋转角度（度）。
    var rotationFrom: Double
    /// 起始模糊半径。
    var blurFrom: Double
    /// 起始不透明度。
    var opacityFrom: Double
}

// MARK: - Motion

/// 页面进场时相对静止位置偏移出来的姿态。
struct OverlayMotion {
    var offset: CGSize = .zero
    var scale: Double = 1
    var rotation: Double = 0
    var rotationAxis: OverlayRotationAxis = .y
    var blur: Double = 0
    var opacity: Double = 1

    static let identity = OverlayMotion()
}

enum OverlayRotationAxis {
    case x, y, z
}

/// 把一套进场姿态套用到任意视图上（进场与退场共用同一套，保证同构）。
struct OverlayMotionModifier: ViewModifier {
    var motion: OverlayMotion

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(motion.rotationAxis == .y ? motion.rotation : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5)
            .rotation3DEffect(
                .degrees(motion.rotationAxis == .x ? motion.rotation : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5)
            .rotationEffect(.degrees(motion.rotationAxis == .z ? motion.rotation : 0))
            .offset(motion.offset)
            .scaleEffect(motion.scale)
            .blur(radius: motion.blur)
            .opacity(motion.opacity)
    }
}

// MARK: - Catalog

enum OverlayMotionCategory: String, CaseIterable, Identifiable {
    case platform, common, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .platform: return "平台原生"
        case .common: return "常见动画"
        case .custom: return "自定义"
        }
    }

    var footer: String {
        switch self {
        case .platform: return "SwiftUI 自带的过渡：透明度 / 缩放 / 位移 / 滑动 / 推入 / 模糊替换。"
        case .common: return "在平台过渡基础上叠加出来的常见手感，多数带淡入。"
        case .custom: return ""
        }
    }
}

/// 所有内置动画。选一个会填入它那套参数，可再单独微调。
enum OverlayAnimationStyle: String, CaseIterable, Identifiable, Codable {
    // —— 平台原生 ——
    case none
    case fade
    case scale
    case moveBottom
    case moveTop
    case moveLeading
    case moveTrailing
    case slide
    case push
    case blurReplace
    // —— 常见 ——
    case pop
    case zoomOut
    case rise
    case drop
    case fadeScale
    case crossDissolve
    case cardPush
    case flipX
    case flipY
    case efficient
    case reliable
    case modalPop
    // —— 自定义 ——
    case custom

    var id: String { rawValue }

    var category: OverlayMotionCategory {
        switch self {
        case .none, .fade, .scale, .moveBottom, .moveTop, .moveLeading,
             .moveTrailing, .slide, .push, .blurReplace:
            return .platform
        case .pop, .zoomOut, .rise, .drop, .fadeScale, .crossDissolve,
             .cardPush, .flipX, .flipY, .efficient, .reliable, .modalPop:
            return .common
        case .custom:
            return .custom
        }
    }

    var title: String {
        switch self {
        case .none: return "无过渡"
        case .fade: return "淡入 opacity"
        case .scale: return "缩放 scale"
        case .moveBottom: return "自下移入 move"
        case .moveTop: return "自上移入 move"
        case .moveLeading: return "自左移入 move"
        case .moveTrailing: return "自右移入 move"
        case .slide: return "滑动 slide"
        case .push: return "推入 push"
        case .blurReplace: return "模糊替换 blurReplace"
        case .pop: return "弹出"
        case .zoomOut: return "由大收小"
        case .rise: return "上冲"
        case .drop: return "下落"
        case .fadeScale: return "淡入放大"
        case .crossDissolve: return "交叉溶解"
        case .cardPush: return "卡片推入"
        case .flipX: return "横向翻转"
        case .flipY: return "纵向翻转"
        case .efficient: return "高效专业"
        case .reliable: return "稳定可靠"
        case .modalPop: return "模态弹出"
        case .custom: return "自定义"
        }
    }

    var detail: String {
        switch self {
        case .none: return "瞬时出现，完全没有过渡"
        case .fade: return "只做透明度渐变，最短最安静"
        case .scale: return "原地由小放大，不带淡入"
        case .moveBottom: return "整页从下往上滑入，像 iOS 面板"
        case .moveTop: return "整页从上往下滑入"
        case .moveLeading: return "整页从左侧滑入"
        case .moveTrailing: return "整页从右侧滑入"
        case .slide: return "平台 slide：从一侧滑入、向另一侧滑出"
        case .push: return "平台 push：新页面把旧页面顶开"
        case .blurReplace: return "先模糊后清晰，iOS 17 的替换过渡"
        case .pop: return "原地由小弹大，有「弹出来」的手感"
        case .zoomOut: return "由大收到正常大小，像镜头拉远"
        case .rise: return "从下方弹簧上冲，带一点缩放"
        case .drop: return "从上方向下坠落"
        case .fadeScale: return "淡入的同时轻微放大，最常见的组合"
        case .crossDissolve: return "纯交叉溶解，慢而柔"
        case .cardPush: return "右侧推入，Material 卡片式"
        case .flipX: return "绕水平轴 3D 翻转进场"
        case .flipY: return "绕垂直轴 3D 翻转进场"
        case .efficient: return "快速、克制、不拖沓，专业工具的确认感"
        case .reliable: return "匀速稳重、没有花哨，内容稳稳到位"
        case .modalPop: return "居中由小弹大，像弹窗 / 模态卡片出现"
        case .custom: return "自由组合下列所有参数"
        }
    }

    /// 这套预设填入的参数。`自定义` 返回 nil。
    var parameters: OverlayAnimationParameters? {
        switch self {
        case .none:
            return P(duration: 0, curve: .linear, travelX: 0, travelY: 0,
                     scale: 1, rotation: 0, blur: 0, opacity: 1)
        case .fade:
            return P(duration: 0.2, curve: .easeOut, travelX: 0, travelY: 0,
                     scale: 1, rotation: 0, blur: 0, opacity: 0)
        case .scale:
            return P(duration: 0.3, curve: .spring, bounce: 0.7, travelX: 0, travelY: 0,
                     scale: 0.94, rotation: 0, blur: 0, opacity: 1)
        case .moveBottom:
            return P(duration: 0.36, curve: .spring, bounce: 0.82, travelX: 0, travelY: 260,
                     scale: 1, rotation: 0, blur: 0, opacity: 1)
        case .moveTop:
            return P(duration: 0.36, curve: .spring, bounce: 0.82, travelX: 0, travelY: -260,
                     scale: 1, rotation: 0, blur: 0, opacity: 1)
        case .moveLeading:
            return P(duration: 0.36, curve: .spring, bounce: 0.82, travelX: -300, travelY: 0,
                     scale: 1, rotation: 0, blur: 0, opacity: 1)
        case .moveTrailing:
            return P(duration: 0.36, curve: .spring, bounce: 0.82, travelX: 300, travelY: 0,
                     scale: 1, rotation: 0, blur: 0, opacity: 1)
        case .slide:
            return P(duration: 0.36, curve: .spring, bounce: 0.85, travelX: -360, travelY: 0,
                     scale: 1, rotation: 0, blur: 0, opacity: 1)
        case .push:
            return P(duration: 0.36, curve: .spring, bounce: 0.85, travelX: 0, travelY: 360,
                     scale: 1, rotation: 0, blur: 0, opacity: 1)
        case .blurReplace:
            return P(duration: 0.34, curve: .easeInOut, travelX: 0, travelY: 0,
                     scale: 1, rotation: 0, blur: 22, opacity: 0)
        case .pop:
            return P(duration: 0.32, curve: .spring, bounce: 0.55, travelX: 0, travelY: 14,
                     scale: 0.9, rotation: 0, blur: 0, opacity: 0)
        case .zoomOut:
            return P(duration: 0.34, curve: .spring, bounce: 0.62, travelX: 0, travelY: 0,
                     scale: 1.08, rotation: 0, blur: 0, opacity: 0)
        case .rise:
            return P(duration: 0.42, curve: .spring, bounce: 0.7, travelX: 0, travelY: 220,
                     scale: 1, rotation: 0, blur: 0, opacity: 0)
        case .drop:
            return P(duration: 0.4, curve: .spring, bounce: 0.68, travelX: 0, travelY: -220,
                     scale: 1, rotation: 0, blur: 0, opacity: 0)
        case .fadeScale:
            return P(duration: 0.3, curve: .easeOut, travelX: 0, travelY: 0,
                     scale: 0.94, rotation: 0, blur: 0, opacity: 0)
        case .crossDissolve:
            return P(duration: 0.34, curve: .easeInOut, travelX: 0, travelY: 0,
                     scale: 1, rotation: 0, blur: 0, opacity: 0)
        case .cardPush:
            return P(duration: 0.34, curve: .spring, bounce: 0.9, travelX: 320, travelY: 0,
                     scale: 1, rotation: 0, blur: 0, opacity: 0)
        case .flipX:
            return P(duration: 0.44, curve: .spring, bounce: 0.8, travelX: 0, travelY: 0,
                     scale: 1, rotation: 90, blur: 0, opacity: 0)
        case .flipY:
            return P(duration: 0.44, curve: .spring, bounce: 0.8, travelX: 0, travelY: 0,
                     scale: 1, rotation: -90, blur: 0, opacity: 0)
        case .efficient:
            return P(duration: 0.2, curve: .easeOut, travelX: 0, travelY: 10,
                     scale: 1, rotation: 0, blur: 0, opacity: 0)
        case .reliable:
            return P(duration: 0.3, curve: .easeInOut, bounce: 0.9, travelX: 0, travelY: 0,
                     scale: 0.98, rotation: 0, blur: 0, opacity: 0)
        case .modalPop:
            return P(duration: 0.34, curve: .spring, bounce: 0.5, travelX: 0, travelY: 0,
                     scale: 0.86, rotation: 0, blur: 0, opacity: 0)
        case .custom:
            return nil
        }
    }

    /// 该动画是否会用到某个参数（决定实验室里显示哪些滑块）。
    var usesHorizontalTravel: Bool {
        switch self {
        case .moveLeading, .moveTrailing, .slide, .cardPush, .custom: return true
        default: return false
        }
    }

    var usesVerticalTravel: Bool {
        switch self {
        case .moveBottom, .moveTop, .push, .rise, .drop, .pop, .efficient, .custom: return true
        default: return false
        }
    }

    var usesScale: Bool {
        switch self {
        case .scale, .pop, .zoomOut, .fadeScale, .reliable, .modalPop, .custom: return true
        default: return false
        }
    }

    var usesRotation: Bool {
        switch self {
        case .flipX, .flipY, .custom: return true
        default: return false
        }
    }

    var usesBlur: Bool {
        switch self {
        case .blurReplace, .custom: return true
        default: return false
        }
    }

    var usesOpacity: Bool { self != .none }

    /// 由这套动画 + 当前参数，算出进场姿态。
    func motion(_ s: OverlayAnimationSettings) -> OverlayMotion {
        switch self {
        case .none:
            return .identity
        case .fade, .crossDissolve:
            return OverlayMotion(opacity: s.opacityFrom)
        case .scale, .pop, .zoomOut, .fadeScale, .reliable, .modalPop:
            return OverlayMotion(scale: s.scaleFrom, opacity: s.opacityFrom)
        case .moveBottom, .push:
            return OverlayMotion(offset: CGSize(width: 0, height: s.travelY), opacity: s.opacityFrom)
        case .moveTop:
            return OverlayMotion(offset: CGSize(width: 0, height: s.travelY), opacity: s.opacityFrom)
        case .moveLeading, .slide:
            return OverlayMotion(offset: CGSize(width: s.travelX, height: 0), opacity: s.opacityFrom)
        case .moveTrailing, .cardPush:
            return OverlayMotion(offset: CGSize(width: s.travelX, height: 0), opacity: s.opacityFrom)
        case .blurReplace:
            return OverlayMotion(blur: s.blurFrom, opacity: s.opacityFrom)
        case .rise, .efficient:
            return OverlayMotion(offset: CGSize(width: 0, height: s.travelY),
                                 scale: s.scaleFrom, opacity: s.opacityFrom)
        case .drop:
            return OverlayMotion(offset: CGSize(width: 0, height: s.travelY),
                                 scale: s.scaleFrom, opacity: s.opacityFrom)
        case .flipX:
            return OverlayMotion(rotation: s.rotationFrom, rotationAxis: .x, opacity: s.opacityFrom)
        case .flipY:
            return OverlayMotion(rotation: s.rotationFrom, rotationAxis: .y, opacity: s.opacityFrom)
        case .custom:
            return OverlayMotion(offset: CGSize(width: s.travelX, height: s.travelY),
                                 scale: s.scaleFrom,
                                 rotation: s.rotationFrom,
                                 rotationAxis: .y,
                                 blur: s.blurFrom,
                                 opacity: s.opacityFrom)
        }
    }
}

// 简写，避免每个预设都写一长串参数名。
private func P(duration: Double,
               curve: OverlayAnimationCurve,
               bounce: Double = 0.8,
               travelX: Double,
               travelY: Double,
               scale: Double,
               rotation: Double,
               blur: Double,
               opacity: Double) -> OverlayAnimationParameters {
    OverlayAnimationParameters(
        duration: duration, curve: curve, bounce: bounce,
        travelX: travelX, travelY: travelY, scaleFrom: scale,
        rotationFrom: rotation, blurFrom: blur, opacityFrom: opacity)
}

// MARK: - Settings

/// 持久化的页面过渡配置。默认「弹出」——原地由小弹大、前移一点。
struct OverlayAnimationSettings: Codable, Hashable {
    var style: OverlayAnimationStyle = .pop
    var duration: Double = 0.32
    var curve: OverlayAnimationCurve = .spring
    var bounce: Double = 0.55
    var travelX: Double = 0
    var travelY: Double = 14
    var scaleFrom: Double = 0.9
    var rotationFrom: Double = 0
    var blurFrom: Double = 0
    var opacityFrom: Double = 0

    // MARK: Animation builders

    /// 进场：当前配置的曲线。
    var enterAnimation: Animation {
        switch curve {
        case .linear: return .linear(duration: duration)
        case .easeIn: return .easeIn(duration: duration)
        case .easeOut: return .easeOut(duration: duration)
        case .easeInOut: return .easeInOut(duration: duration)
        case .smooth: return .smooth(duration: duration)
        case .snappy: return .snappy(duration: duration)
        case .bouncy: return .bouncy(duration: duration)
        case .spring: return .spring(response: max(0.05, duration), dampingFraction: bounce)
        case .interpolatingSpring:
            return .interpolatingSpring(mass: 1, stiffness: 220, damping: 2 * 220.0.squareRoot() * bounce)
        case .interactiveSpring:
            return .interactiveSpring(response: max(0.05, duration), dampingFraction: bounce)
        }
    }

    /// 退场：同样的手感，但更快收尾、不留回弹，免得关页面时拖泥带水。
    var exitAnimation: Animation {
        let d = max(0, duration - 0.06)
        switch curve {
        case .linear: return .linear(duration: d)
        case .easeIn: return .easeOut(duration: d)
        case .easeOut: return .easeOut(duration: d)
        case .easeInOut: return .easeInOut(duration: d)
        case .smooth: return .smooth(duration: max(0.05, d))
        case .snappy: return .snappy(duration: max(0.05, d))
        case .bouncy: return .snappy(duration: max(0.05, d))
        case .spring: return .spring(response: max(0.05, d), dampingFraction: min(1, bounce + 0.2))
        case .interpolatingSpring:
            return .interpolatingSpring(mass: 1, stiffness: 260, damping: 2 * 260.0.squareRoot())
        case .interactiveSpring:
            return .interactiveSpring(response: max(0.05, d), dampingFraction: min(1, bounce + 0.2))
        }
    }

    // MARK: Motion

    /// 进场姿态（静止时为 identity）。
    var entryMotion: OverlayMotion { style.motion(self) }

    /// 退场过渡：把进场姿态原样镜像回来，保证进出同构。
    var removalTransition: AnyTransition {
        AnyTransition.modifier(
            active: OverlayMotionModifier(motion: entryMotion),
            identity: OverlayMotionModifier(motion: .identity))
    }

    // MARK: Mutation helpers

    /// 用一套预设填满所有参数（`style` 由调用方设置）。
    mutating func apply(_ parameters: OverlayAnimationParameters) {
        duration = parameters.duration
        curve = parameters.curve
        bounce = parameters.bounce
        travelX = parameters.travelX
        travelY = parameters.travelY
        scaleFrom = parameters.scaleFrom
        rotationFrom = parameters.rotationFrom
        blurFrom = parameters.blurFrom
        opacityFrom = parameters.opacityFrom
    }
}

// MARK: - Persistence

extension OverlayAnimationSettings {
    static let storageKey = "BiliBili.overlayAnimation"

    /// 读取存档。`dismissImmersive` 是个没有 AppStore 引用的自由函数，需要它。
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
