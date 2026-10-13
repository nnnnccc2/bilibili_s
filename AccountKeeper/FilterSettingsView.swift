//
//  FilterSettingsView.swift
//  BiliBili
//
//  Filter & purification settings: rules, word management, stats
//

import SwiftUI

struct FilterSettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var newWord: String = ""
    @State private var showWordError: String? = nil

    var body: some View {
        NavigationStack {
            List {
                // Purification dashboard
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.title2)
                                .foregroundStyle(.green)
                            Text("净化引擎")
                                .font(.headline)
                            Spacer()
                            Text("运行中")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        HStack(spacing: 0) {
                            statBlock(label: "累计净化", value: "\(store.settings.stats.totalBlocked)", color: .pink)
                            Divider().frame(height: 36)
                            statBlock(label: "标题党", value: "\(store.settings.stats.byClickbait)", color: .orange)
                            Divider().frame(height: 36)
                            statBlock(label: "日语标题", value: "\(store.settings.stats.byJapaneseTitle)", color: .blue)
                            Divider().frame(height: 36)
                            statBlock(label: "日语UP主", value: "\(store.settings.stats.byJapaneseUP)", color: .purple)
                        }

                        HStack(spacing: 0) {
                            statBlock(label: "时长过短", value: "\(store.settings.stats.byDuration)", color: .teal)
                            Divider().frame(height: 36)
                            statBlock(label: "侮辱词", value: "\(store.settings.stats.byInsultWord)", color: .red)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("净化统计看板")
                }

                // Title / clickbait filtering
                Section {
                    Toggle("自动过滤垃圾与引导式标题", isOn: $store.settings.enableClickbaitFilter)
                    if store.settings.enableClickbaitFilter {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(FilterSettings.builtInClickbaitWords.prefix(12), id: \.self) { word in
                                    Text(word)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.12))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                                Text("等 \(FilterSettings.builtInClickbaitWords.count) 个关键词")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Toggle("过滤日语标题视频", isOn: $store.settings.enableJapaneseTitleFilter)
                } header: {
                    Text("标题过滤")
                } footer: {
                    Text("命中疯了、炸了、屌爆了、！等夸张引导词，或含日文字符的标题视频将被自动拦截。")
                }

                // UP主 filtering
                Section {
                    Toggle("自动过滤博主名称含日语字的博主", isOn: $store.settings.enableJapaneseUPFilter)
                } header: {
                    Text("UP主过滤")
                } footer: {
                    Text("开启后，昵称包含日文字符的创作者发布的视频将全部拦截。")
                }

                // Duration filtering (global)
                Section {
                    NavigationLink {
                        DurationPickerView(selection: $store.settings.durationThresholdSeconds)
                    } label: {
                        HStack {
                            Text("根据视频时长屏蔽短视频")
                            Spacer()
                            Text(currentDurationLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("时长屏蔽")
                } footer: {
                    Text("视频总时长小于或等于所选档位时自动拦截隐藏。")
                }

                // Insult / derogatory word list
                Section {
                    Toggle("按词语屏蔽视频", isOn: $store.settings.enableInsultWordFilter)
                    Toggle("内置侮辱、贬低词语清单", isOn: $store.settings.builtInWordsEnabled)
                        .disabled(!store.settings.enableInsultWordFilter)

                    if store.settings.builtInWordsEnabled {
                        Text("内置 \(FilterSettings.builtInInsultWords.count) 个核心词")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Add custom word
                    HStack {
                        TextField("添加自定义屏蔽词", text: $newWord)
                            .onSubmit { addWord() }
                        Button(action: addWord) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.pink)
                        }
                    }

                    // Custom words list
                    if !store.settings.customBlockedWords.isEmpty {
                        ForEach(store.settings.customBlockedWords, id: \.self) { word in
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                Text(word)
                                Spacer()
                                Button {
                                    store.removeCustomWord(word)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                } header: {
                    Text("侮辱、贬低词语屏蔽清单")
                } footer: {
                    if let err = showWordError {
                        Text(err).foregroundStyle(.red)
                    }
                }

                // UI
                Section {
                    Toggle("显示已过滤提示条", isOn: $store.settings.showFilteredBanner)
                } header: {
                    Text("显示")
                }

                // Reset stats
                Section {
                    Button(role: .destructive) {
                        store.settings.stats = FilterStats()
                    } label: {
                        Label("重置净化统计数据", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("过滤与设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var currentDurationLabel: String {
        if let sec = store.settings.durationThresholdSeconds {
            return FilterSettings.durationBlockOptions.first { $0.seconds == sec }?.label ?? "不限制"
        }
        return "不限制"
    }

    private func statBlock(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            showWordError = "请输入有效词语"
            return
        }
        if store.settings.customBlockedWords.contains(trimmed) {
            showWordError = "词语已存在"
            return
        }
        if FilterSettings.builtInInsultWords.contains(trimmed) {
            showWordError = "该词已在内置词库中"
            return
        }
        showWordError = nil
        store.addCustomWord(trimmed)
        newWord = ""
    }
}

// MARK: - Duration picker

struct DurationPickerView: View {
    @Binding var selection: Int?

    var body: some View {
        List {
            ForEach(Array(FilterSettings.durationBlockOptions.enumerated()), id: \.offset) { _, opt in
                Button {
                    selection = opt.seconds
                } label: {
                    HStack {
                        Text(opt.label)
                        Spacer()
                        if selection == opt.seconds {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.pink)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("屏蔽时长档位")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FilterSettingsView()
            .environmentObject(AppStore())
    }
}
