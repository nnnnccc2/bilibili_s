//
//  SettingsView.swift
//  BiliBili
//
//  About page
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var onDismiss: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("关于") {
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("BiliBili")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("\(BuildInfo.appVersion) (\(BuildInfo.buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("构建信息") {
                    HStack(alignment: .top) {
                        Text("源码生成时间")
                        Spacer()
                        Text(BuildInfo.sourceTime)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack(alignment: .top) {
                        Text("IPA 编译时间")
                        Spacer()
                        Text(BuildInfo.compileTime)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("说明") {
                    Text("极简风格的第三方哔哩哔哩客户端，主打内容净化与纯净播放体验。具备全站维度的垃圾视频与低质内容自动过滤机制，提供真实无弹幕干扰的视频流播放。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { if let onDismiss = onDismiss { onDismiss() } else { dismiss() } }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
