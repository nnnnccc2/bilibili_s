//
//  SettingsView.swift
//  AccountKeeper
//
//  App settings and build info
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var store: AccountStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("关于") {
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("账号管家")
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

                Section("数据") {
                    HStack {
                        Text("已记录账号数")
                        Spacer()
                        Text("\(store.accounts.count)")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        exportData()
                    } label: {
                        Label("导出账号数据", systemImage: "square.and.arrow.up")
                    }
                }

                Section("说明") {
                    Text("本应用专注于记录你在哪些应用和网站注册了账号，密码为可选项。数据仅保存在本地设备，不会上传。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func exportData() {
        // Simple export - copy to clipboard for now
        let text = store.accounts.map { account in
            "📱 \(account.name)\n账号: \(account.username)\n网址: \(account.url)\n备注: \(account.note)\n"
        }.joined(separator: "\n---\n")
        UIPasteboard.general.string = text
    }
}

#Preview {
    SettingsView()
        .environmentObject(AccountStore())
}
