//
//  FilterSettingsView.swift
//  BiliBili
//
//  Filter & purification settings: rules, word management, stats
//

import SwiftUI
import UIKit
import Foundation
import UniformTypeIdentifiers

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
    @State private var expandedCreatorTypes: Set<CreatorType> = []
    @State private var showWhitelist: Bool = false
    @State private var selectedCreatorMid: Int = 0
    @State private var selectedCreatorName: String = ""
    @State private var showCreatorSheet: Bool = false
    @State private var pickerTarget: CreatorProfile?
    @State private var blockTarget: CreatorProfile?
    @State private var showBlockConfirm: Bool = false
    @State private var showClearWhitelistConfirm: Bool = false

    // 待确认屏蔽清单相关
    @State private var showConfirmBlocked: Bool = false
    @State private var showClearConfirmBlockedConfirm: Bool = false
    @State private var bulkConfirmType: CreatorType?
    @State private var showBulkConfirmSheet: Bool = false
    @State private var applyAllConfirmAlert: Bool = false
    @State private var removeConfirmTarget: CreatorProfile?

    // 导入导出
    @State private var importTarget: CreatorImportTarget = .whitelist
    @State private var pendingReplace: Bool = false
    @State private var showWhitelistImportChoice: Bool = false
    @State private var showSettingsImportChoice: Bool = false
    @State private var documentPicker = JSONDocumentPicker()
    @State private var importResult: String?
    @State private var showImportResult: Bool = false

    private var selectedDurationCount: Int {
        store.settings.blockedDurationSeconds.count
    }

    var body: some View {
        contentWithDialogs
    }

    /// 各类确认弹窗（拆分出来降低 body 类型推断压力）。
    private var contentWithDialogs: some View {
        mainBody
            .confirmationDialog(
                "导入白名单",
                isPresented: $showWhitelistImportChoice,
                titleVisibility: .visible
            ) {
                Button("追加到现有白名单") {
                    startImport(.whitelist, replace: false)
                }
                Button("覆盖现有白名单", role: .destructive) {
                    startImport(.whitelist, replace: true)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("选择 JSON 文件后导入。追加保留现有条目，覆盖会先清空现有白名单。")
            }
            .confirmationDialog(
                "导入博主分类",
                isPresented: $showSettingsImportChoice,
                titleVisibility: .visible
            ) {
                Button("追加到现有设置") {
                    startImport(.creatorSettings, replace: false)
                }
                Button("覆盖现有设置", role: .destructive) {
                    startImport(.creatorSettings, replace: true)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("选择 JSON 文件后导入，恢复各分类博主名单与待确认屏蔽名单，同时恢复博主类型屏蔽、UP 黑名单和白名单。")
            }
            .alert("导入结果", isPresented: $showImportResult) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(importResult ?? "完成")
            }
    }

    /// 主视图内容（拆分出来降低 body 类型推断压力）。
    private var mainBody: some View {
        let _ = CrashReporter.mark("PROBE8·展开设置页")
        return NavigationView {
            ZStack {
                biliBackgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        cardsFilterGroup
                        cardsCreatorGroup
                        cardsOtherGroup
                        resetStatsButton
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("垃圾过滤与设置中心")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { CrashReporter.mark("设置页·已显示") }
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
            .sheet(isPresented: $showCreatorSheet) {
                if selectedCreatorMid != 0 {
                    UPSpaceView(mid: selectedCreatorMid, initialName: selectedCreatorName)
                        .environmentObject(store)
                }
            }
            .sheet(item: $pickerTarget) { profile in
                CreatorTypePickerView(profile: profile)
                    .environmentObject(store)
            }
            .confirmationDialog(
                "加入黑名单？",
                isPresented: $showBlockConfirm,
                presenting: blockTarget
            ) { profile in
                Button("屏蔽「\(profile.name)」的全部视频", role: .destructive) {
                    store.blockCreatorPermanently(mid: profile.mid, name: profile.name)
                }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text("该 UP 主的所有视频都会被过滤，可在「UP 主黑名单」里取消。")
            }
            .confirmationDialog(
                "清空白名单？",
                isPresented: $showClearWhitelistConfirm,
                titleVisibility: .visible
            ) {
                Button("删除全部 \(store.settings.whitelistedCreators.count) 位博主", role: .destructive) {
                    store.clearCreatorWhitelist()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作不可撤销，删除后这些博主会重新参与自动分类。")
            }
            .confirmationDialog(
                "加入待确认屏蔽清单？",
                isPresented: $showBulkConfirmSheet,
                presenting: bulkConfirmType
            ) { type in
                Button("将「\(type.rawValue)」下全部已识别博主加入清单", role: .destructive) {
                    _ = store.confirmBlockAllCreators(ofType: type)
                }
                Button("取消", role: .cancel) {}
            } message: { type in
                Text("加入后这些博主会从分类列表移到待确认屏蔽清单，确认生效后才会正式拦截。白名单和已拉黑的博主不会被加入。")
            }
            .confirmationDialog(
                "从待确认清单移除？",
                isPresented: Binding(
                    get: { removeConfirmTarget != nil },
                    set: { if !$0 { removeConfirmTarget = nil } }
                ),
                presenting: removeConfirmTarget
            ) { profile in
                Button("从待确认清单移除「\(profile.name)」", role: .destructive) {
                    store.removeFromConfirmBlocked(mid: profile.mid)
                }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text("移除后该博主会回到所在分类的博主列表，不会被屏蔽，也不会进入白名单。")
            }
            .confirmationDialog(
                "全部确认生效？",
                isPresented: $applyAllConfirmAlert,
                titleVisibility: .visible
            ) {
                Button("将 \(store.settings.confirmBlockedCreators.count) 位博主全部写入黑名单", role: .destructive) {
                    _ = store.applyAllConfirmBlocks()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确认后会把清单内全部 UP 按 mid 写入屏蔽列表，之后即使博主缓存被清理也会被拦截。")
            }
            .confirmationDialog(
                "清空待确认清单？",
                isPresented: $showClearConfirmBlockedConfirm,
                titleVisibility: .visible
            ) {
                Button("清空全部 \(store.settings.confirmBlockedCreators.count) 位", role: .destructive) {
                    store.clearConfirmBlockedCreators()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("清空后这些博主会回到各自分类的博主列表，不会被屏蔽。")
            }
        }
    }

    // MARK: - 设置卡片分组（拆开构建，降低单个 body 的栈与类型推断压力）

    @ViewBuilder
    private var cardsFilterGroup: some View {
        // Purification dashboard
        dashboardCard.crashMark("设置页·净化面板")

        // Clickbait filter
        clickbaitCard.crashMark("设置页·标题党规则")

        // Exclamation-mark filter (separate, default off)
        exclamationCard.crashMark("设置页·感叹号规则")

        // Japanese filters
        japaneseCard.crashMark("设置页·日语规则")

        // Duration filter (multi-select)
        durationCard.crashMark("设置页·时长规则")

        // Category / partition blacklist
        categoryCard.crashMark("设置页·分区黑名单")

        // 一级 / 二级分区屏蔽
        partitionCard.crashMark("设置页·分区屏蔽")

        // UP主 blacklist
        upBlockCard.crashMark("设置页·UP黑名单")
    }

    @ViewBuilder
    private var cardsCreatorGroup: some View {
        // 博主类型过滤看板
        creatorTypeCard.crashMark("设置页·博主类型看板")
    }

    @ViewBuilder
    private var cardsOtherGroup: some View {
        // General keyword filter
        keywordCard.crashMark("设置页·关键词规则")

        // 视频标签(Tag)屏蔽
        tagCard.crashMark("设置页·Tag规则")

        // Insult word list
        insultWordCard.crashMark("设置页·辱骂词")

        // UI toggle
        uiCard.crashMark("设置页·界面开关")
    }

    private var resetStatsButton: some View {
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
                miniStat(label: "博主类型拦截", value: store.settings.stats.byCreatorType, color: .mint)
            }

            HStack(spacing: 6) {
                Image(systemName: store.settings.enablePartitionFilter ? "shield.lefthalf.filled" : "shield.slash")
                    .font(.system(size: 10))
                Text("分区屏蔽 \(store.settings.enablePartitionFilter ? "已启用" : "未启用") · 一级 \(store.settings.blockedTopZoneTids.count) 个 · 二级 \(store.settings.blockedSubZoneTids.count) 个")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)

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
                            // 优先显示博主昵称，没有名字时退回 mid
                            Text(store.settings.blockedUPNames[mid] ?? "\(mid)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
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

    // MARK: - Creator type filter

    private var creatorTypeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            creatorTypeTop
            if store.settings.enableCreatorTypeFilter {
                creatorTypeActions
                creatorTypeGrid
                creatorTypeExtraLists
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    /// 看板头部：开关与说明。
    @ViewBuilder
    private var creatorTypeTop: some View {
        let _ = CrashReporter.mark("看板·开始")
        Toggle(isOn: $store.settings.enableCreatorTypeFilter) {
            Label("博主类型过滤", systemImage: "person.2.slash")
                .font(.headline)
        }
        .tint(.biliBlue)

        Text("自动识别 UP 主的内容类型（数码评测 / 美食 / 游戏 / 影视剪辑等），按类型批量屏蔽。点击类型标签可展开该类型下的博主，点博主头像可跳转主页；点右侧 ⋯ 可移入其他分类或加入黑名单。")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// 看板操作行：恢复默认、清空缓存、导入、导出。
    @ViewBuilder
    private var creatorTypeActions: some View {
        let _ = CrashReporter.mark("看板·构建按钮行")
        HStack(spacing: 10) {
            Button {
                store.resetBlockedCreatorTypes()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("恢复默认屏蔽")
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
                store.clearKnownCreators()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                    Text("清空识别缓存")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .clipShape(Capsule())
            }
            Button {
                exportCreatorSettingsToFile()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.biliBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.biliBlue.opacity(0.12))
                .clipShape(Capsule())
            }
            Button {
                showSettingsImportChoice = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down")
                    Text("导入")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.biliBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.biliBlue.opacity(0.12))
                .clipShape(Capsule())
            }
            Spacer()
            Text("已识别 \(store.settings.knownCreators.count) 位博主")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 类型标签网格。
    @ViewBuilder
    private var creatorTypeGrid: some View {
        // 按类型统计一次。原来每个 chip 各自扫一遍全量缓存（13 次 O(n) 过滤），
        // 缓存里博主流多时会明显拖慢点击响应。
        let _ = CrashReporter.mark("看板·构建统计")
        let typeCounts = Dictionary(
            grouping: store.settings.knownCreators.values,
            by: { $0.type }
        ).mapValues { $0.count }

        let _ = CrashReporter.mark("看板·构建网格")
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(CreatorType.allCases.filter { $0 != .other }) { type in
                creatorTypeChip(type, count: typeCounts[type] ?? 0)
            }
        }
    }

    /// 白名单与待确认屏蔽清单的折叠入口。
    @ViewBuilder
    private var creatorTypeExtraLists: some View {
        // 白名单：被「移除」的博主都在这里，点标题展开查看
        if !store.settings.whitelistedCreators.isEmpty {
            let _ = CrashReporter.mark("看板·构建白名单头")
            Divider().padding(.vertical, 4)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    showWhitelist.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                    Text("白名单")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("\(store.settings.whitelistedCreators.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showWhitelist ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .frame(minHeight: 34)
            }
            .buttonStyle(.plain)

            if showWhitelist {
                let _ = CrashReporter.mark("看板·展开白名单")
                whitelistSection
            }
        }

        // 待确认屏蔽清单：从某类型一键转入，尚未正式生效。
        if !store.settings.confirmBlockedCreators.isEmpty {
            let _ = CrashReporter.mark("看板·构建待确认头")
            Divider().padding(.vertical, 4)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    showConfirmBlocked.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                    Text("待确认屏蔽")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("\(store.settings.confirmBlockedCreators.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showConfirmBlocked ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .frame(minHeight: 34)
            }
            .buttonStyle(.plain)

            if showConfirmBlocked {
                let _ = CrashReporter.mark("看板·展开待确认")
                confirmBlockedSection
            }
        }
    }

    private func creatorTypeChip(_ type: CreatorType, count: Int) -> some View {
        let _ = CrashReporter.mark("设置页·类型标签·\(type.rawValue)")
        let blocked = store.settings.blockedCreatorTypes.contains(type)
        let expanded = expandedCreatorTypes.contains(type)
        return VStack(alignment: .leading, spacing: 8) {
            // 整行可点击展开/收起；多个类型可同时展开
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    if expanded {
                        expandedCreatorTypes.remove(type)
                    } else {
                        expandedCreatorTypes.insert(type)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: type.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(type.color)
                    Text(type.rawValue)
                        .font(.caption)
                        .fontWeight(blocked ? .semibold : .regular)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                store.toggleCreatorType(type)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: blocked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                    Text(blocked ? "已屏蔽" : "未屏蔽")
                        .font(.system(size: 11))
                }
                .foregroundStyle(blocked ? Color.red : Color.secondary)
            }
            .buttonStyle(.plain)

            // 展开的博主列表：和之前一样直接展开在类型标签下方
            if expanded {
                creatorList(for: type)
            }
        }
        .padding(10)
        .background(blocked ? type.color.opacity(0.1) : Color(.systemGray5))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(blocked ? type.color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 展开在类型标签下方的博主列表。
    /// 上半部分是该分类的博主，可一键加入待确认屏蔽；下半部分列出该分类中
    /// 已加入待确认屏蔽的博主，可直接「生效」或「移除」。
    @ViewBuilder
    private func creatorList(for type: CreatorType) -> some View {
        let creators = store.settings.knownCreators.values
            .filter { $0.type == type }
            .sorted { $0.confidence > $1.confidence }
        let pending = store.settings.confirmBlockedCreators.values
            .filter { $0.type == type }
            .sorted { $0.name < $1.name }
        VStack(spacing: 6) {
            if creators.isEmpty {
                Text("该分类暂无待处理博主")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(creators) { profile in
                    creatorRow(profile)
                }

                // 一键把本分类所有博主加入待确认屏蔽清单（不立即生效）。
                Button(role: .destructive) {
                    bulkConfirmType = type
                    showBulkConfirmSheet = true
                } label: {
                    Label(
                        "将该分类 \(creators.count) 位博主加入待确认屏蔽",
                        systemImage: "hand.raised.slash"
                    )
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            // 该分类下已加入待确认屏蔽的博主
            if !pending.isEmpty {
                Divider().padding(.vertical, 2)
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("已加入待确认屏蔽 \(pending.count) 位")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ForEach(pending) { profile in
                    confirmPendingRow(profile)
                }
            }
        }
        .padding(.top, 4)
    }

    /// 分类内「待确认屏蔽」条目：可生效或移除（移除后回到分类列表）。
    private func confirmPendingRow(_ profile: CreatorProfile) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
            Text(profile.name)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button {
                store.applyConfirmBlock(mid: profile.mid)
            } label: {
                Text("生效")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("确认生效")

            Button {
                removeConfirmTarget = profile
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("从待确认清单移除")
        }
    }

    private func creatorRow(_ profile: CreatorProfile) -> some View {
        HStack(spacing: 4) {
            Button {
                selectedCreatorMid = profile.mid
                selectedCreatorName = profile.name
                showCreatorSheet = true
            } label: {
                HStack(spacing: 6) {
                    CachedAsyncImage(
                        url: URL(string: profile.avatar.isEmpty ? "" : profile.avatar),
                        targetSize: CGSize(width: 48, height: 48)
                    ) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Text(profile.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if profile.manuallyTyped {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("\(Int(profile.confidence * 100))% · \(profile.sampleCount)条")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 2)

            // 额外操作：移入其他分类 / 加入黑名单
            Menu {
                Button {
                    pickerTarget = profile
                } label: {
                    Label("移入其他分类", systemImage: "arrow.left.arrow.right")
                }
                Button(role: .destructive) {
                    blockTarget = profile
                    showBlockConfirm = true
                } label: {
                    Label("加入黑名单", systemImage: "hand.raised")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("更多操作")

            // 常规操作：移入白名单（不再屏蔽该博主）
            Button {
                store.removeCreator(mid: profile.mid)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("移入白名单")
        }
    }

    /// 白名单博主列表（原样式，直接内嵌在卡片里）。
    /// 删除后该博主下次出现在视频流中会被重新分类，可能再次进入屏蔽列表。
    /// 「清空白名单」需二次确认，避免误触。
    @ViewBuilder
    private var whitelistSection: some View {
        let creators = store.settings.whitelistedCreators.values
            .sorted { $0.name < $1.name }
        if creators.isEmpty {
            Text("白名单为空")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 6) {
                ForEach(creators) { profile in
                    HStack(spacing: 8) {
                        Button {
                            selectedCreatorMid = profile.mid
                            selectedCreatorName = profile.name
                            showCreatorSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                CachedAsyncImage(
                                    url: URL(string: profile.avatar.isEmpty ? "" : profile.avatar),
                                    targetSize: CGSize(width: 48, height: 48)
                                ) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(profile.type.rawValue)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button {
                            store.removeFromWhitelist(mid: profile.mid)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(.red.opacity(0.7))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("从白名单删除")
                    }
                }
                HStack {
                    Button {
                        exportWhitelistToFile()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("导出")
                        }
                        .font(.caption2)
                        .foregroundColor(.biliBlue)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showWhitelistImportChoice = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("导入")
                        }
                        .font(.caption2)
                        .foregroundColor(.biliBlue)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    Button {
                        showClearWhitelistConfirm = true
                    } label: {
                        Text("清空白名单")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
    }

    /// 待确认屏蔽清单展开视图。
    /// 每行：头像 + 昵称 + 类型，操作列「生效」、「移除」。
    /// 顶部有「全部确认生效」按钮、底部有「清空清单」按钮。
    private var confirmBlockedSection: some View {
        let creators = store.settings.confirmBlockedCreators.values
            .sorted { $0.type == $1.type ? $0.name < $1.name : $0.type.rawValue < $1.type.rawValue }
        return VStack(spacing: 6) {
            // 顶部：全部确认生效
            HStack {
                Button(role: .destructive) {
                    applyAllConfirmAlert = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.shield.fill")
                        Text("全部确认生效（\(creators.count)）")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
            }

            ForEach(creators) { profile in
                HStack(spacing: 8) {
                    Button {
                        selectedCreatorMid = profile.mid
                        selectedCreatorName = profile.name
                        showCreatorSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            CachedAsyncImage(
                                url: URL(string: profile.avatar.isEmpty ? "" : profile.avatar),
                                targetSize: CGSize(width: 48, height: 48)
                            ) { img in img.resizable().scaledToFill() } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(profile.type.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()

                    Button {
                        store.applyConfirmBlock(mid: profile.mid)
                    } label: {
                        Text("生效")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        removeConfirmTarget = profile
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.orange)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("从待确认清单移除")
                }
            }

            // 底部：清空清单
            HStack {
                Spacer()
                Button {
                    showClearConfirmBlockedConfirm = true
                } label: {
                    Text("清空清单")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
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

    // MARK: - 白名单导入导出

    /// 导出白名单到 JSON 文件（系统分享面板，可存到「文件」或发给其他设备）。
    private func exportWhitelistToFile() {
        guard let json = store.exportWhitelistJSON() else {
            importResult = "导出失败：JSON 编码异常"
            showImportResult = true
            return
        }
        shareJSONFile(text: json, filename: "bilibili-whitelist-\(Self.timestampSuffix())")
    }

    // MARK: - 博主分类导入导出

    /// 导出全部博主分类设置到 JSON 文件：各分类下的博主名单 + 待确认屏蔽名单 +
    /// 类型屏蔽 / UP 黑名单 / 白名单。
    private func exportCreatorSettingsToFile() {
        guard let json = store.exportAllCreatorSettingsJSON() else {
            importResult = "导出失败：JSON 编码异常"
            showImportResult = true
            return
        }
        shareJSONFile(text: json, filename: "bilibili-creators-\(Self.timestampSuffix())")
    }

    /// 写入临时文件并弹出系统分享面板（保存到「文件」/ 隔空投送 / 微信等）。
    private func shareJSONFile(text: String, filename: String) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("json")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            importResult = "导出失败：\(error.localizedDescription)"
            showImportResult = true
            return
        }
        guard let top = Self.topViewController() else {
            importResult = "导出失败：找不到可用的窗口"
            showImportResult = true
            return
        }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = activity.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(
                x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0
            )
        }
        top.present(activity, animated: true)
    }

    /// 记录导入目标与覆盖策略，待确认弹窗收起后再拉起系统文件选择器。
    private func startImport(_ target: CreatorImportTarget, replace: Bool) {
        importTarget = target
        pendingReplace = replace
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            presentImportPicker()
        }
    }

    private func presentImportPicker() {
        guard let top = Self.topViewController() else {
            importResult = "导入失败：找不到可用的窗口"
            showImportResult = true
            return
        }
        documentPicker.onPick = { url in
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                importResult = "导入失败：无法读取文件内容"
                showImportResult = true
                return
            }
            performImport(text: text)
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .plainText], asCopy: true)
        picker.delegate = documentPicker
        picker.allowsMultipleSelection = false
        top.present(picker, animated: true)
    }

    private func performImport(text: String) {
        do {
            switch importTarget {
            case .whitelist:
                let count = try store.importWhitelistJSON(text, replace: pendingReplace)
                importResult = "成功导入 \(count) 位博主到\(pendingReplace ? "新" : "现有")白名单"
            case .creatorSettings:
                let r = try store.importAllCreatorSettingsJSON(text, replace: pendingReplace)
                importResult = """
                导入完成：
                · 分类博主 \(r.knownCreators) 位
                · 待确认屏蔽 \(r.confirmBlocked) 位
                · 博主类型屏蔽 \(r.blockedCreatorTypes) 项
                · UP 黑名单 \(r.blockedUPMids) 位
                · 白名单 \(r.whitelist) 位
                """
            }
        } catch {
            importResult = "导入失败：\(error.localizedDescription)"
        }
        showImportResult = true
    }

    /// 当前最上层的 ViewController，用于弹出系统分享 / 文件选择面板。
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        let keyWindow = windows.first { $0.isKeyWindow } ?? windows.first
        guard var vc = keyWindow?.rootViewController else { return nil }
        while let presented = vc.presentedViewController {
            vc = presented
        }
        return vc
    }

    private static func timestampSuffix() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }
}

/// 导入导出目标类型。
private enum CreatorImportTarget {
    case whitelist
    case creatorSettings
}

/// 系统文件选择器的 delegate 包装（SwiftUI 里没有直接可用的回调入口）。
final class JSONDocumentPicker: NSObject, UIDocumentPickerDelegate {
    var onPick: ((URL) -> Void)?

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onPick?(url)
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

/// 把某个博主手动移入其他分类。移入后分类被锁定，自动识别不再覆盖。
struct CreatorTypePickerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let profile: CreatorProfile

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(CreatorType.allCases) { type in
                        Button {
                            store.moveCreator(mid: profile.mid, to: type)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: type.icon)
                                    .foregroundStyle(type.color)
                                    .frame(width: 22)
                                Text(type.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if type == profile.type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.biliBlue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("把「\(profile.name)」移入")
                } footer: {
                    Text("移入后该博主的分类会被锁定，不再被自动识别覆盖。")
                }
            }
            .navigationTitle("移入其他分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        FilterSettingsView()
            .environmentObject(AppStore())
    }
}
