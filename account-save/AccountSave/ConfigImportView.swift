import SwiftUI

/// 配置导入说明：隐私说明 + 快捷指令自动化配置步骤。
struct ConfigImportView: View {
    @Environment(\.dismiss) private var dismiss

    private let privacyItems: [(symbol: String, text: String)] = [
        ("lock.shield", "iOS 确保了账号保存无法读取历史短信数据库"),
        ("iphone", "只有快捷指令中允许的短信才会被记录到"),
        ("wifi.slash", "本 APP 不申请任何形式的网络权限"),
        ("externaldrive", "所有数据只保存在本地，确保隐私安全")
    ]

    private let steps: [String] = [
        "打开「快捷指令」，进入「自动化」。",
        "新建个人自动化，选择「收到信息」。",
        "条件选择「信息内容包含」，填入「【」。",
        "进入下一步后，选择「创建新的快捷指令」。",
        "在新快捷指令里添加「账号保存」的「导入商家短信」动作。",
        "点开「发件人」，选择「快捷指令输入」中的「发件人」。",
        "点开「短信内容」，选择「快捷指令输入」中的「内容」。",
        "点开「收件人」，选择「快捷指令输入」中的「收件人」。这是接收短信的手机号，会自动写入账号的注册手机号。",
        "点开「账号名」，选择「每次询问」，运行时会弹窗输入账号名。",
        "关闭「运行前询问」，并保存自动化。"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sectionTitle("隐私说明")
                    privacyCard
                    sectionTitle("配置步骤")
                    stepsCard
                    Text("导出账号列表（Excel）与全部短信（CSV）：回到「短信收纳盒」，点右上角的分享按钮。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("配置导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
    }

    private var privacyCard: some View {
        VStack(spacing: 0) {
            ForEach(privacyItems.indices, id: \.self) { index in
                if index > 0 {
                    Divider().padding(.leading, 16)
                }
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: privacyItems[index].symbol)
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    Text(privacyItems[index].text)
                        .font(.system(size: 16))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
        }
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var stepsCard: some View {
        VStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { index in
                if index > 0 {
                    Divider().padding(.leading, 16)
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.blue, in: Circle())
                    Text(steps[index])
                        .font(.system(size: 16))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
        }
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}
