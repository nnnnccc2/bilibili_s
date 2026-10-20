import AppIntents
import SwiftData

/// 供「快捷指令」调用的动作：把收到的短信保存到指定账号下。
///
/// 在快捷指令里把「账号名」设为「每次询问」，运行自动化时就会弹窗输入账号名，
/// 短信随即保存到该账号条目下。
/// 「收件人」即接收短信的手机号，用作该账号的注册手机号；留空时会自动尝试
/// 从短信内容里识别出手机号。
struct ImportMerchantSMSIntent: AppIntent {
    static var title: LocalizedStringResource { "保存登录凭证短信" }

    static var description: IntentDescription? {
        IntentDescription("把收到的账号验证码短信保存到本机凭证库，方便按账号查询注册手机号和历史记录。")
    }

    /// 自动化运行时不需要把 App 切到前台。
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "账号名")
    var accountName: String

    @Parameter(title: "发件人")
    var sender: String

    @Parameter(title: "短信内容")
    var content: String

    /// 接收短信的手机号（注册手机号）。快捷指令自动化里选「快捷指令输入 → 收件人」。
    /// 留空时 App 会尝试从短信内容里自动识别。
    @Parameter(title: "收件人", default: "")
    var recipient: String

    /// 所有参数都必须出现在摘要里，否则快捷指令界面不会显示对应的输入框。
    static var parameterSummary: some ParameterSummary {
        Summary("把 \(\.$sender) 发给 \(\.$recipient) 的短信「\(\.$content)」保存到账号 \(\.$accountName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 用 App 的主上下文写入，界面上的列表会同步刷新。
        let context = AppStore.container.mainContext
        let account = try SMSSaver.save(
            in: context,
            accountName: accountName,
            sender: sender,
            content: content,
            recipient: recipient
        )
        return .result(dialog: "已保存到账号「\(account.name)」")
    }
}
