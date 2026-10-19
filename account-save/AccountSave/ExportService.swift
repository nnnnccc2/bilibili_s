import Foundation

/// 导出账号列表与短信。
enum ExportService {
    /// 账号列表：`.xlsx`，Excel / Numbers 可直接打开查看。
    static func exportAccounts(_ accounts: [Account]) throws -> URL {
        var rows: [[String]] = [["账号名", "注册手机号"]]
        for account in accounts.sorted(by: { $0.createdAt < $1.createdAt }) {
            rows.append([account.name, account.phoneNumber])
        }
        let data = Spreadsheet.makeXLSX(sheetName: "账号列表", rows: rows)
        return try write(data, named: "账号列表_\(DateText.stamp()).xlsx")
    }

    /// 全部短信：CSV 文本，Excel / Numbers / WPS 均可直接打开。
    static func exportMessages(_ accounts: [Account]) throws -> URL {
        var lines = ["账号名,注册手机号,发件号码,短信内容,接收时间,验证码"]

        for account in accounts.sorted(by: { $0.createdAt < $1.createdAt }) {
            for message in account.sortedMessages {
                lines.append([
                    field(account.name),
                    field(account.phoneNumber),
                    field(message.sender),
                    field(message.content),
                    field(DateText.full(message.receivedAt)),
                    field(VerificationCode.extract(from: message.content) ?? "")
                ].joined(separator: ","))
            }
        }

        let csv = "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
        return try write(Data(csv.utf8), named: "短信_\(DateText.stamp()).csv")
    }

    private static func write(_ data: Data, named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AccountSaveExport", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// CSV 字段转义。
    private static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
