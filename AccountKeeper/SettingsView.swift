//
//  SettingsView.swift
//  BiliBili
//
//  总设置中心 —— 账号 / 过滤 / 历史 / 数据 / 关于
//  （PROBE8 · 构建 1 展开版）
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var onDismiss: (() -> Void)? = nil

    /// 嵌入的过滤配置中心（从 NavigationLink 进入）
    @State private var showingFilterCenter = false
    @State private var showingLogin = false

    @State private var showClearHistoryConfirm = false
    @State private var showClearCacheToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                biliBackgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        accountCard
                        filterQuickCard
                        filterCenterCard
                        historyCard
                        dataCard
                        aboutCard
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let onDismiss = onDismiss { onDismiss() } else { dismiss() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.biliBlue)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if let onDismiss = onDismiss { onDismiss() } else { dismiss() }
                    }
                    .foregroundStyle(.biliBlue)
                }
            }
        }
        .overlay {
            if showingLogin {
                LoginView(onDismiss: { dismissImmersive { showingLogin = false } })
                    .environmentObject(store)
                    .immersive()
                    .zIndex(30)
            }
        }
        .overlay(alignment: .bottom) {
            if showClearCacheToast {
                Text("图片缓存已清理")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("清空观看历史", isPresented: $showClearHistoryConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                store.clearHistory()
            }
        } message: {
            Text("本地保存的 \(store.history.count) 条观看历史将被永久删除，不可恢复。")
        }
    }

    // MARK: - 账号与同步

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "person.text.rectangle.fill")
                    .foregroundStyle(.biliBlue)
                Text("账号与同步")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            if let user = store.currentUser {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.biliBlue.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(user.name.prefix(1)))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.biliBlue)
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(user.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("硬币 \(user.coins) · LV\(user.level)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Button {
                    store.logout()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("退出登录")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.biliBlue.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundStyle(.biliBlue)
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("未登录")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("登录后同步观看历史与收藏")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showingLogin = true
                    } label: {
                        Text("去登录")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.biliBlue)
                            .clipShape(Capsule())
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

    // MARK: - 过滤引擎速览（关键开关 + 统计）

    private var filterQuickCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(.biliBlue)
                Text("净化引擎速览")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("累计拦截 \(store.settings.stats.totalBlocked) 条")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.biliBlue)
            }

            VStack(spacing: 0) {
                filterToggleRow(
                    title: "垃圾/引导式标题过滤",
                    subtitle: "\"疯了\"、\"炸了\"等夸张词",
                    icon: "exclamationmark.circle.fill",
                    iconColor: .red,
                    isOn: $store.settings.enableClickbaitFilter
                )
                filterToggleRow(
                    title: "日文字符UP主拦截",
                    subtitle: "识别平假名/片假名昵称",
                    icon: "character.book.closed.fill",
                    iconColor: .purple,
                    isOn: $store.settings.enableJapaneseUPFilter
                )
                filterToggleRow(
                    title: "日文字符标题拦截",
                    subtitle: "含假名的视频标题",
                    icon: "character.book.closed",
                    iconColor: .purple,
                    isOn: $store.settings.enableJapaneseTitleFilter
                )
                filterToggleRow(
                    title: "侮辱贬低词库",
                    subtitle: "内置 32 词 + 自定义清单",
                    icon: "hand.raised.fill",
                    iconColor: .green,
                    isOn: $store.settings.enableInsultWordFilter
                )
                filterToggleRow(
                    title: "感叹号标题过滤",
                    subtitle: "! / !! / !!! 连续感叹号（默认关闭）",
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    isOn: $store.settings.enableExclamationFilter
                )
            }
            .background(Color.biliCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // 时长阈值摘要
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    if let threshold = store.settings.effectiveDurationThreshold {
                        Text("短视频屏蔽阈值：≤ \(threshold)s 的视频自动拦截")
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Text("已选 \(store.settings.blockedDurationSeconds.count) 档 · 去过滤中心调整")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("短视频过滤未启用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func filterToggleRow(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.biliBlue)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    // MARK: - 完整过滤中心入口

    private var filterCenterCard: some View {
        Button {
            showingFilterCenter = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(.biliBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text("过滤与词库配置中心")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text("全部规则、时长多选、自定义词库、统计看板")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .navigationDestination(isPresented: $showingFilterCenter) {
            FilterSettingsView(onDismiss: { showingFilterCenter = false })
                .environmentObject(store)
        }
    }

    // MARK: - 观看记录

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.biliBlue)
                Text("观看记录")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(store.history.count) 条")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("本地缓存的观看历史")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    showClearHistoryConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("清空")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.08))
                    .clipShape(Capsule())
                    .disabled(store.history.isEmpty)
                    .opacity(store.history.isEmpty ? 0.4 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - 数据与缓存

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(.biliBlue)
                Text("数据与缓存")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.storageFootprint)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("设置 + 历史 + 图片缓存（估算）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    store.clearImageCache()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showClearCacheToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showClearCacheToast = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("清缓存")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.biliBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.biliBlue.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - 关于

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.biliBlue)
                Text("关于 BiliBili")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BiliBili 第三方客户端")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("版本 \(BuildInfo.appVersion) · 构建 \(BuildInfo.buildNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            infoRow(label: "源码生成时间", value: BuildInfo.sourceTime)
            infoRow(label: "IPA 编译时间", value: BuildInfo.compileTime)
            infoRow(label: "过滤规则 schema", value: "v\(FilterSettings.currentSchemaVersion)")

            Divider()

            Text("极简风格的第三方哔哩哔哩客户端，主打内容净化与纯净播放体验。具备全站维度的垃圾视频与低质内容自动过滤机制，提供真实无弹幕干扰的视频流播放。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.biliBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
                .frame(maxWidth: 200, alignment: .trailing)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
