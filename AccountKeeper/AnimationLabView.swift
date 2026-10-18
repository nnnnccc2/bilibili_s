//
//  AnimationLabView.swift
//  BiliBili
//
//  "动画实验室": try every built-in page-transition animation and tune its
//  parameters, then keep whichever feels right. Changes apply immediately, so
//  the real screens (视频页 / UP主页 / 搜索 / 设置) can be used as the preview.
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
                Section {
                    ForEach(OverlayAnimationStyle.allCases.filter { $0 != .custom }) { style in
                        presetRow(style)
                    }
                } header: {
                    Text("预设")
                } footer: {
                    Text("点任意预设会立刻播一次预览。改动下面任何参数都会变成「自定义」。")
                }

                Section {
                    paramSlider("时长", \.duration, range: 0.1...0.6, format: "%.2f 秒")
                    if store.animation.curve == .spring {
                        paramSlider("回弹", \.bounce, range: 0.4...1.0, format: "%.2f")
                    }
                    paramSlider("上冲位移", \.rise, range: 0...240, format: "%.0f pt")
                    paramSlider("起始缩放", \.scaleFrom, range: 0.9...1.1, format: "%.2f")

                    Picker("曲线", selection: curveBinding) {
                        ForEach(OverlayAnimationCurve.allCases) { curve in
                            Text(curve.title).tag(curve)
                        }
                    }
                } header: {
                    Text("参数")
                } footer: {
                    Text(store.animation.curve.detail)
                }

                Section {
                    Button("预览当前动画") { showingPreview = true }
                } header: {
                    Text("试用")
                } footer: {
                    Text("设置立即生效，也可以直接去视频页 / UP主页 / 搜索 / 设置 打开体验。回弹越小越弹；「起始缩放」小于 1 时画面会从边缘往里弹，会看到身后页面的一圈边，设成 1.00 可去掉。")
                }

                Section {
                    Button("恢复默认（弹出）", role: .destructive) {
                        store.animation = OverlayAnimationSettings()
                    }
                }
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

    /// Applies a preset and immediately plays it, so each one can be felt
    /// without leaving the lab. If a preview is already on screen it is taken
    /// down first, then replayed.
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

/// Throwaway page the lab uses to play the current animation once. Closes itself
/// so the next preset can be tried right away.
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
