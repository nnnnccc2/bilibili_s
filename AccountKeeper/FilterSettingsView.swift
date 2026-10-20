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
    @State private var newUPMid: String = ""
    @State private var newKeyword: String = ""
    @State private var newTag: String = ""
    @State private var expandedTopZones: Set<Int> = []

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

                        // Category / partition blacklist
                        categoryCard

                        // 一级 / 二级分区屏蔽
                        partitionCard

                        // UP主 blacklist
                        upBlockCard

                        // General keyword filter
                        keywordCard

                        // 视频标签(Tag)屏蔽
                        tagCard

                        // Insult word list
                        insultWordCard

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

            // 一键最强净化：只开总开关但没开内置词库/分区时，过滤不会命中任何内容。
            Button {
                store.enableStrongPurification()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("一键最强净化")
                            .font(.subheadline).fontWeight(.bold)
                        Text("开启关键词+内置词库、Tag、分区（动画/番剧/游戏/美食/影视/娱乐/鬼畜）")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                }
                .foregroundStyle(Color.biliBlue)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.biliBlue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

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

            // 6 stat cards grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                miniStat(label: "标题党/引导词", value: store.settings.stats.byClickbait, color: .red)
                miniStat(label: "时长过滤拦截", value: store.settings.stats.byDuration, color: .orange)
                miniStat(label: "日文字符UP主", value: store.settings.stats.byJapaneseUP + store.settings.stats.byJapaneseTitle, color: .purple)
                miniStat(label: "侮辱贬低词库", value: store.settings.stats.byInsultWord, color: .green)
                miniStat(label: "分类黑名单", value: store.settings.stats.byCategory, color: .indigo)
                miniStat(label: "分区屏蔽拦截", value: store.settings.stats.byPartition, color: .teal)
                miniStat(label: "关键词拦截", value: store.settings.stats.byKeyword, color: .cyan)
                miniStat(label: "标签(Tag)拦截", value: store.settings.stats.byTag, color: .indigo)
            }

            Text("构建 \(Bundle.main.object(forInfoDictionaryKey: "BuildCompileTime") as? String ?? "未知") · 上次首页 带tag \(store.feedDiagnostics.withTags)/\(store.feedDiagnostics.total) 条")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
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
                    Text("点左侧电源图标可暂时停用（变灰），点右侧 × 删除。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    FlowLayout(spacing: 8) {
                        ForEach(store.settings.customBlockedWords, id: \.self) { word in
                            BlockedEntryChip(
                                text: word,
                                isDisabled: store.settings.disabledWords.contains(word),
                                onToggle: { store.toggleCustomWord(word) },
                                onDelete: { store.removeCustomWord(word) }
                            )
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

    // MARK: - Category blacklist

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $store.settings.enableCategoryFilter) {
                Label("分类黑名单屏蔽", systemImage: "folder.badge.minus")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Text("按 B 站分区（如“动画”“游戏”“美食”“影视”）整体屏蔽。从视频卡片详情或搜索结果中识别的分类会被应用。")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Add category
            HStack {
                TextField("输入要屏蔽的分类名...", text: $newCategory)
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
                                store.unblockCategory(category)
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
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Partition blacklist (一级 / 二级分区)

    private var partitionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $store.settings.enablePartitionFilter) {
                Label("B站分区屏蔽（一级 / 二级）", systemImage: "square.grid.2x2.fill")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Text("按 B 站官方分区目录屏蔽：可整体屏蔽一级分区，或展开后精细屏蔽二级分区。作用于首页推荐、热门、搜索视频流。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.settings.enablePartitionFilter {
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.blockRecommendedZones()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.fill")
                            Text("一键屏蔽高频低质区")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.biliBlue)
                        .clipShape(Capsule())
                    }
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.clearPartitionBlocklist()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                            Text("清空")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    Spacer()
                    Text("一级 \(store.settings.blockedTopZoneTids.count) · 二级 \(store.settings.blockedSubZoneTids.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    ForEach(BiliZone.all) { zone in
                        topZoneRow(zone)
                    }
                }
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func topZoneRow(_ zone: BiliTopZone) -> some View {
        let topBlocked = store.settings.blockedTopZoneTids.contains(zone.tid)
        let expanded = expandedTopZones.contains(zone.tid)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        store.toggleTopZone(tid: zone.tid)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: topBlocked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(topBlocked ? Color.biliBlue : .gray)
                        Text(zone.name)
                            .font(.subheadline)
                            .fontWeight(topBlocked ? .semibold : .regular)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if !zone.subs.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            if expanded { expandedTopZones.remove(zone.tid) }
                            else { expandedTopZones.insert(zone.tid) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("二级 \(zone.subs.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if expanded && !zone.subs.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(zone.subs) { sub in
                        subZoneChip(sub)
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.biliBorder)
                .frame(height: 0.5)
        }
    }

    private func subZoneChip(_ sub: BiliSubZone) -> some View {
        let selected = store.settings.blockedSubZoneTids.contains(sub.tid)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                store.toggleSubZone(tid: sub.tid)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                Text(sub.name)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selected ? Color.biliBlue.opacity(0.15) : Color(.systemGray5))
            .foregroundStyle(selected ? Color.biliBlue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - UP主 blacklist

    private var upBlockCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $store.settings.enableUPBlockFilter) {
                Label("UP主黑名单", systemImage: "person.badge.minus")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Text("长按任意视频卡片选择“屏蔽该 UP 主”，或在此输入 mid 屏蔽指定 UP 主。")
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
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
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

    // MARK: - General keyword filter

    private var keywordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $store.settings.enableKeywordFilter) {
                Label("通用关键词过滤", systemImage: "text.magnifyingglass")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Text("命中标题、UP 主名、简介、分类或 tag 中的关键词即拦截。适合过滤“动画”“游戏录播”“美食”“影视”“Vlog”等内容。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("启用内置关键词库", isOn: $store.settings.builtInKeywordsEnabled)
                .disabled(!store.settings.enableKeywordFilter)
                .tint(.biliBlue)

            // Add custom keyword
            HStack {
                TextField("输入要屏蔽的关键词...", text: $newKeyword)
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

            if store.settings.builtInKeywordsEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("内置关键词库 (\(FilterSettings.builtInKeywords.count)个):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(FilterSettings.builtInKeywords, id: \.self) { word in
                            Text(word)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.cyan.opacity(0.12))
                                .foregroundStyle(.cyan)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            if !store.settings.customBlockedKeywords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义关键词 (\(store.settings.customBlockedKeywords.count)个):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("点左侧电源图标可暂时停用（变灰），点右侧 × 删除。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    FlowLayout(spacing: 8) {
                        ForEach(store.settings.customBlockedKeywords, id: \.self) { word in
                            BlockedEntryChip(
                                text: word,
                                isDisabled: store.settings.disabledKeywords.contains(word),
                                onToggle: { store.toggleBlockedKeyword(word) },
                                onDelete: { store.removeBlockedKeyword(word) }
                            )
                        }
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

    // MARK: - Tag filter

    private var tagCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $store.settings.enableTagFilter) {
                Label("标签屏蔽 (Tag)", systemImage: "tag.slash")
                    .font(.headline)
            }
            .tint(.biliBlue)

            Text("只匹配视频的真实 tag 字段，比关键词更精准。首页推荐 / 热门本身不返回 tag，App 会自动补拉后应用；搜索流自带 tag。适合精准屏蔽游戏录播、日本动画、影视解说、美食探店等内容。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("启用内置标签库", isOn: $store.settings.builtInTagsEnabled)
                .disabled(!store.settings.enableTagFilter)
                .tint(.biliBlue)

            HStack {
                TextField("输入要屏蔽的标签...", text: $newTag)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit { addTag() }
                Button(action: addTag) {
                    Text("+ 添加")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.biliBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .disabled(!store.settings.enableTagFilter)

            if store.settings.builtInTagsEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("内置标签库 (\(FilterSettings.builtInTags.count)个):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(FilterSettings.builtInTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.indigo.opacity(0.12))
                                .foregroundStyle(.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            if !store.settings.customBlockedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义标签 (\(store.settings.customBlockedTags.count)个):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("点左侧电源图标可暂时停用（变灰），点右侧 × 删除。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    FlowLayout(spacing: 8) {
                        ForEach(store.settings.customBlockedTags, id: \.self) { tag in
                            BlockedEntryChip(
                                text: tag,
                                isDisabled: store.settings.disabledTags.contains(tag),
                                onToggle: { store.toggleBlockedTag(tag) },
                                onDelete: { store.removeBlockedTag(tag) }
                            )
                        }
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
        guard !trimmed.isEmpty else { return }
        store.blockCategory(trimmed)
        newCategory = ""
    }

    private func addUPMid() {
        let trimmed = newUPMid.trimmingCharacters(in: .whitespaces)
        guard let mid = Int(trimmed), mid > 0 else { return }
        store.blockUP(mid: mid)
        newUPMid = ""
    }

    private func addKeyword() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addBlockedKeyword(trimmed)
        newKeyword = ""
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addBlockedTag(trimmed)
        newTag = ""
    }
}

/// 自定义屏蔽条目 chip：左侧电源图标切换「使用 / 关闭使用」，右侧 × 删除。
/// 关闭使用后条目仍保留在列表中但整体变灰，便于随时恢复。
private struct BlockedEntryChip: View {
    let text: String
    let isDisabled: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Button(action: onToggle) {
                Image(systemName: isDisabled ? "power.circle" : "power.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(isDisabled ? Color.secondary : Color.biliBlue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDisabled ? "恢复使用" : "关闭使用")

            Text(text)
                .font(.caption)
                .strikethrough(isDisabled, color: .secondary)
                .foregroundStyle(isDisabled ? Color.secondary : Color.primary)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.red.opacity(isDisabled ? 0.45 : 0.85))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(isDisabled ? Color(.systemGray6) : Color(.systemGray5))
        .opacity(isDisabled ? 0.55 : 1)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        FilterSettingsView()
            .environmentObject(AppStore())
    }
}
