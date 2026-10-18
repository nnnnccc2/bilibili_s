//
//  AnimationLabView.swift
//  BiliBili
//
//  "动画实验室": 逐个试遍内置的每一种页面过渡动画，并现场调参，
//  即时生效——真机上的视频页 / UP主页 / 搜索 / 设置 本身就是预览台。
//

import Foundation
import SwiftUI

struct AnimationLabView: View {
    @EnvironmentObject var store: AppStore

    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showingPreview = false

    var body: some View {
        NavigationStack {
            List {
                catalogSection(.platform)
                catalogSection(.common)
                parameterSection
                trialSection
                resetSection
            }
            .navigationTitle("动画实验室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if let onDismiss { onDismiss() } else { dismiss() }
                    }
                }
            }
        }
        .overlay {
            if showingPreview {
                AnimationPreviewPage(onDismiss: { dismissImmersive { showingPreview = false } })
                    .immersive()
                    .zIndex(30)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func catalogSection(_ category: OverlayMotionCategory) -> some View {
        let styles = OverlayAnimationStyle.allCases.filter { $0.category == category }
        Section {
            ForEach(styles) { style in
                presetRow(style)
            }
        } header: {
            Text(category.title)
        } footer: {
            Text(category.footer)
        }
    }

    @ViewBuilder
    private var parameterSection: some View {
        let style = store.animation.style
        Section {
            paramSlider("时长", \.duration, range: 0...0.6, format: "%.2f 秒")
            if store.animation.curve.isSpringLike {
                paramSlider("回弹", \.bounce, range: 0.3...1.0, format: "%.2f")
            }
            if style.usesHorizontalTravel {
                paramSlider("水平位移", \.travelX, range: -420...420, format: "%.0f pt")
            }
            if style.usesVerticalTravel {
                paramSlider("垂直位移", \.travelY, range: -420...420, format: "%.0f pt")
            }
            if style.usesScale {
                paramSlider("起始缩放", \.scaleFrom, range: 0.8...1.2, format: "%.2f")
            }
            if style.usesRotation {
                paramSlider("起始旋转", \.rotationFrom, range: -180...180, format: "%.0f°")
            }
            if style.usesBlur {
                paramSlider("起始模糊", \.blurFrom, range: 0...40, format: "%.0f")
            }
            if style.usesOpacity {
                paramSlider("起始透明度", \.opacityFrom, range: 0...1, format: "%.2f")
            }

            Picker("曲线", selection: curveBinding) {
                ForEach(OverlayAnimationCurve.allCases) { curve in
                    Text(curve.title).tag(curve)
                }
            }
        } header: {
            Text("参数 · \(style.title)")
        } footer: {
            Text(store.animation.curve.detail)
        }
    }

    @ViewBuilder
    private var trialSection: some View {
        Section {
            Button("预览当前动画") { showingPreview = true }
        } header: {
            Text("试用")
        } footer: {
            Text("设置立即生效，也可以直接去视频页 / UP主页 / 搜索 / 设置 打开体验。改动下面任何参数都会变成「自定义」。")
        }
    }

    @ViewBuilder
    private var resetSection: some View {
        Section {
            Button("恢复默认（弹出）", role: .destructive) {
                store.animation = OverlayAnimationSettings()
            }
        }
    }

    // MARK: - Rows

    private func presetRow(_ style: OverlayAnimationStyle) -> some View {
        Button {
            select(style)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.title)
                        .foregroundStyle(.primary)
                    Text(style.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.animation.style == style {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.biliBlue)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func paramSlider(
        _ title: String,
        _ keyPath: WritableKeyPath<OverlayAnimationSettings, Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: format, store.animation[keyPath: keyPath]))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: paramBinding(keyPath), in: range)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Bindings

    private func paramBinding(_ keyPath: WritableKeyPath<OverlayAnimationSettings, Double>) -> Binding<Double> {
        Binding(
            get: { store.animation[keyPath: keyPath] },
            set: { newValue in
                store.animation[keyPath: keyPath] = newValue
                markCustom()
            }
        )
    }

    private var curveBinding: Binding<OverlayAnimationCurve> {
        Binding(
            get: { store.animation.curve },
            set: { newValue in
                store.animation.curve = newValue
                markCustom()
            }
        )
    }

    // MARK: - Actions

    /// 应用一套预设并立刻播一次，省得来回切页面。若预览还开着就先收掉再重播。
    private func select(_ style: OverlayAnimationStyle) {
        guard let parameters = style.parameters else { return }
        var config = store.animation
        config.apply(parameters)
        config.style = style
        store.animation = config

        if showingPreview {
            dismissImmersive { showingPreview = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showingPreview = true }
        } else {
            showingPreview = true
        }
    }

    private func markCustom() {
        guard store.animation.style != .custom else { return }
        store.animation.style = .custom
    }
}

// MARK: - Preview page

/// 实验室用来播一次当前动画的临时页面，自动关闭，方便接着试下一个。
private struct AnimationPreviewPage: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.biliBackground.ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundColor(.biliBlue)
                Text("动画预览")
                    .font(.title2.bold())
                Text("这就是当前的进场效果，稍后自动关闭")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            onDismiss()
        }
    }
}

#Preview {
    AnimationLabView()
        .environmentObject(AppStore())
}
