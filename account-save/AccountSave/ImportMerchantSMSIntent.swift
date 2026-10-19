import AppIntents
import SwiftData

/// 供「快捷指令」调用的动作：把收到的短信保存到指定账号下。
///
/// 在快捷指令里把「账号名」设为「每次询问」，运行自动化时就会弹窗输入账号名，
/// 短信随即保存到该账号条目下。
struct ImportMerchantSMSIntent: AppIntent {
    static var title: LocalizedStringResource { "导入商家短信" }

    static var description: IntentDescription? {
        IntentDescription("把收到的短信保存到指定账号下，数据只保存在本机。")
    }

    /// 自动化运行时不需要把 App 切到前台。
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "账号名")
    var accountName: String

    @Parameter(title: "发送号码")
    var sender: String

    @Parameter(title: "短信内容")
    var content: String

    static var parameterSummary: some ParameterSummary {
        Summary("把 \(\.$sender) 的短信保存到账号 \(\.$accountName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 用 App 的主上下文写入，界面上的列表会同步刷新。
        let context = AppStore.container.mainContext
        let account = try SMSSaver.save(
            in: context,
            accountName: accountName,
            sender: sender,
            content: content
        )
        return .result(dialog: "已保存到账号「\(account.name)」")
    }
}
