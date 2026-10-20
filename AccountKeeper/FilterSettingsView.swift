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

    var onDismiss: (() -> Void)? = nil
    @State private var newWord: String = ""
    @State private var showWordError: String? = nil

    @State private var newCategory: String = ""
    @State private var showCategoryError: String? = nil

    @State private var newUPMid: String = ""
    @State private var showUPMidError: String? = nil

    @State private var newKeyword: String = ""
    @State private var showKeywordError: String? = nil

    private var selectedDurationCount: Int {
        store.settings.blockedDurationSeconds.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                biliBackgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Purification dashboard
                        dashboardCard

                        // Clickbait filter
                        clickbaitCard

                        // Exclamation-mark filter (separate, default off)
                        exclamationCard

                        // Japanese filters
                        japaneseCard

                        // Duration filter (multi-select)
                        durationCard

                        // Category blacklist
                        categoryCard

                        // Insult word list
                        insultWordCard

                        // UP主 blacklist
                        upBlockCard

                        // General keyword filter
                        keywordCard

                        // UI toggle
                        uiCard

                        // Reset
                        Button(role: .destructive) {
                            store.settings.stats = FilterStats()
                        } label: {
                            Label("重置净化统计数据", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("垃圾过滤与设置中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let onDismiss = onDismiss { onDismiss() } else { dismiss() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.biliBlue)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { if let onDismiss = onDismiss { onDismiss() } else { dismiss() } }
                        .foregroundColor(.biliBlue)
                }
            }
        }
    }

    // MARK: - Dashboard

    private var dashboardCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.biliBlue)
                Text("净化引擎实时看板")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    // log detail (mock)
                } label: {
                    Text("拦截明细日志")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.biliBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.biliBlue.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // Big number
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("累计拦截低质视频")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(store.settings.stats.totalBlocked)")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.biliBlue)
                        Text("条")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.biliBlue.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundColor(.biliBlue)
                }
            }
            .padding(16)
            .background(Color.biliBlue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Stat cards grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                miniStat(label: "标题党/引导词", value: store.settings.stats.byClickbait, color: .red)
                miniStat(label: "时长过滤拦截", value: store.settings.stats.byDuration, color: .orange)
                miniStat(label: "日文字符UP主", value: store.settings.stats.byJapaneseUP + store.settings.stats.byJapaneseTitle, color: .purple)
                miniStat(label: "侮辱贬低词库", value: store.settings.stats.byInsultWord, color: .green)
                miniStat(label: "分类黑名单", value: store.settings.stats.byCategory, color: .indigo)
                miniStat(label: "UP主黑名单", value: store.settings.stats.byUPBlocked, color: .pink)
                miniStat(label: "关键词拦截", value: store.settings.stats.byKeyword, color: .teal)
                miniStat(label: "感叹号标题", value: store.settings.stats.byExclamationSpam, color: .cyan)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func miniStat(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.biliCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Clickbait

    private var clickbaitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $store.settings.enableClickbaitFilter) {
                Label("自动过滤垃圾与引导式标题", systemImage: "exclamationmark.circle.fill")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Text("自动拦截包含\"疯了\"、\"炸了\"、\"屌爆了\"等夸张煽动词的视频")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.settings.enableClickbaitFilter {
                FlowLayout(spacing: 8) {
                    ForEach(FilterSettings.builtInClickbaitWords, id: \.self) { word in
                        Text(word)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.pink.opacity(0.12))
                            .foregroundStyle(.pink)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Exclamation marks (separate toggle, default off)

    private var exclamationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $store.settings.enableExclamationFilter) {
                Label("过滤含感叹号的标题", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Text("标题中出现 !、！、!!、！！、!!!、！！！ 时自动拦截（较激进，默认关闭）")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.settings.enableExclamationFilter {
                FlowLayout(spacing: 8) {
                    ForEach(FilterSettings.exclamationWords, id: \.self) { word in
                        Text(word)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.12))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Japanese

    private var japaneseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $store.settings.enableJapaneseUPFilter) {
                Text("自动过滤博主名称含日语字")
                    .font(.headline)
            }
            .tint(.biliBlue)
            Text("识别UP主昵称中的平假名/片假名字符并自动拦截其视频")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(isOn: $store.settings.enableJapaneseTitleFilter) {
                Text("过滤日语标题视频")
                    .font(.headline)
            }
            .tint(.biliBlue)
            Text("自动过滤含有日文字符的视频标题")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Duration (multi-select)

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("根据视频时长屏蔽短视频", systemImage: "clock.fill")
                    .font(.headline)
                Spacer()
                Text("已选 \(selectedDurationCount) 档")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.biliBlue)
            }

            Text("勾选的档位表示屏蔽视频时长小于或等于该档位的视频（拦截无实质内容的碎片短视频）：")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(FilterSettings.durationBlockOptions, id: \.seconds) { opt in
                    let selected = store.settings.blockedDurationSeconds.contains(opt.seconds)
                    Button {
                        if selected {
                            store.settings.blockedDurationSeconds.remove(opt.seconds)
                        } else {
                            store.settings.blockedDurationSeconds.insert(opt.seconds)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected ? .orange : .gray)
                            Text(opt.label)
                                .font(.subheadline)
                                .foregroundStyle(selected ? .orange : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? Color.orange.opacity(0.1) : Color(.systemGray5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? Color.orange : Color.clear, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Category blacklist

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $store.settings.enableCategoryFilter) {
                Label("按分类黑名单屏蔽", systemImage: "folder.badge.minus")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Text("精确匹配视频分区/分类名称（如：动画、游戏、美食），不区分大小写。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("输入要屏蔽的分类...", text: $newCategory)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit { addCategory() }
                Button(action: addCategory) {
                    Text("+ 添加")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.biliBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .disabled(!store.settings.enableCategoryFilter)

            if !store.settings.blockedCategories.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(Array(store.settings.blockedCategories).sorted(), id: \.self) { category in
                        HStack(spacing: 4) {
                            Text(category)
                                .font(.caption)
                            Button {
                                store.removeBlockedCategory(category)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.12))
                        .foregroundStyle(.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if let err = showCategoryError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Insult words

    private var insultWordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $store.settings.enableInsultWordFilter) {
                Label("侮辱、贬低词语屏蔽清单", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Toggle("内置侮辱、贬低词语清单", isOn: $store.settings.builtInWordsEnabled)
                .disabled(!store.settings.enableInsultWordFilter)
                .tint(.biliBlue)

            Text("内置常见攻击、侮辱性词汇，包含标题或简介命中该词时直接屏蔽：")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Add custom word
            HStack {
                TextField("输入要屏蔽的侮辱/低质词语...", text: $newWord)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit { addWord() }
                Button(action: addWord) {
                    Text("+ 添加")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.biliBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if store.settings.builtInWordsEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("内置核心词库 (\(FilterSettings.builtInInsultWords.count)个):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(FilterSettings.builtInInsultWords, id: \.self) { word in
                            Text(word)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            if !store.settings.customBlockedWords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义屏蔽词 (\(store.settings.customBlockedWords.count)个):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(store.settings.customBlockedWords, id: \.self) { word in
                            HStack(spacing: 4) {
                                Text(word)
                                    .font(.caption)
                                Button {
                                    store.removeCustomWord(word)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            if let err = showWordError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - UP主 blacklist

    private var upBlockCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $store.settings.enableUPBlockFilter) {
                Label("屏蔽指定 UP 主", systemImage: "person.fill.xmark")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Text("输入 UP 主的 mid（用户 ID），将其所有视频加入黑名单。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("输入 UP 主 mid...", text: $newUPMid)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit { addUPMid() }
                Button(action: addUPMid) {
                    Text("+ 添加")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.biliBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .disabled(!store.settings.enableUPBlockFilter)

            if !store.settings.blockedUPMids.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(Array(store.settings.blockedUPMids).sorted(), id: \.self) { mid in
                        HStack(spacing: 4) {
                            Text("\(mid)")
                                .font(.caption)
                                .fontWeight(.medium)
                            Button {
                                store.unblockUP(mid: mid)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.pink.opacity(0.12))
                        .foregroundStyle(.pink)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if let err = showUPMidError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - General keyword filter

    private var keywordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $store.settings.enableKeywordFilter) {
                Label("通用关键词过滤", systemImage: "text.magnifyingglass")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Text("在标题、UP主昵称、简介、分类和标签中模糊匹配关键词，命中即屏蔽。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("启用内置关键词建议", isOn: $store.settings.builtInKeywordsEnabled)
                .disabled(!store.settings.enableKeywordFilter)
                .tint(.biliBlue)

            if store.settings.builtInKeywordsEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("内置关键词 (\(FilterSettings.builtInKeywords.count)个)：")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(FilterSettings.builtInKeywords, id: \.self) { word in
                            Text(word)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.teal.opacity(0.12))
                                .foregroundStyle(.teal)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            HStack {
                TextField("输入自定义关键词...", text: $newKeyword)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit { addKeyword() }
                Button(action: addKeyword) {
                    Text("+ 添加")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.biliBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .disabled(!store.settings.enableKeywordFilter)

            if !store.settings.blockedKeywords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义关键词 (\(store.settings.blockedKeywords.count)个)：")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(store.settings.blockedKeywords, id: \.self) { word in
                            HStack(spacing: 4) {
                                Text(word)
                                    .font(.caption)
                                Button {
                                    store.removeBlockedKeyword(word)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            if let err = showKeywordError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - UI

    private var uiCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("显示已过滤提示条", isOn: $store.settings.showFilteredBanner)
                .tint(.biliBlue)
            Text("在首页顶部展示已净化视频条数与规则快捷入口")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

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

    private func addCategory() {
        let trimmed = newCategory.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            showCategoryError = "请输入有效分类"
            return
        }
        if store.settings.blockedCategories.contains(trimmed) {
            showCategoryError = "该分类已在黑名单中"
            return
        }
        showCategoryError = nil
        store.addBlockedCategory(trimmed)
        newCategory = ""
    }

    private func addUPMid() {
        let trimmed = newUPMid.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            showUPMidError = "请输入有效 mid"
            return
        }
        guard let mid = Int(trimmed), mid > 0 else {
            showUPMidError = "mid 必须是正整数"
            return
        }
        if store.settings.blockedUPMids.contains(mid) {
            showUPMidError = "该 UP 主已在黑名单中"
            return
        }
        showUPMidError = nil
        store.blockUP(mid: mid)
        newUPMid = ""
    }

    private func addKeyword() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            showKeywordError = "请输入有效关键词"
            return
        }
        if store.settings.blockedKeywords.contains(trimmed) {
            showKeywordError = "关键词已存在"
            return
        }
        showKeywordError = nil
        store.addBlockedKeyword(trimmed)
        newKeyword = ""
    }
}

#Preview {
    NavigationStack {
        FilterSettingsView()
            .environmentObject(AppStore())
    }
}
