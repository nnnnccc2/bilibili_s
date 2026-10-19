import Foundation

/// 导出账号表格与短信归档。
enum ExportService {
    /// 账号表格：CSV 文本，Excel / Numbers / WPS 均可直接打开。
    static func exportAccounts(_ accounts: [Account]) throws -> URL {
        var lines = ["账号名,注册手机号"]
        for account in accounts.sorted(by: { $0.createdAt < $1.createdAt }) {
            lines.append("\(field(account.name)),\(field(account.phoneNumber))")
        }
        let csv = "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
        return try write(Data(csv.utf8), named: "账号表格_\(DateText.stamp()).csv")
    }

    /// 全部短信：`.cab` 归档，内含 `messages.csv` 与 `messages.json`。
    static func exportMessages(_ accounts: [Account]) throws -> URL {
        var lines = ["账号名,注册手机号,发件号码,短信内容,接收时间,验证码"]
        var records: [[String: String]] = []

        for account in accounts.sorted(by: { $0.createdAt < $1.createdAt }) {
            for message in account.sortedMessages {
                let code = VerificationCode.extract(from: message.content) ?? ""
                lines.append([
                    field(account.name),
                    field(account.phoneNumber),
                    field(message.sender),
                    field(message.content),
                    field(DateText.full(message.receivedAt)),
                    field(code)
                ].joined(separator: ","))
                records.append([
                    "账号名": account.name,
                    "注册手机号": account.phoneNumber,
                    "发件号码": message.sender,
                    "短信内容": message.content,
                    "接收时间": DateText.full(message.receivedAt),
                    "验证码": code
                ])
            }
        }

        let csv = "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
        let json = try JSONSerialization.data(
            withJSONObject: records,
            options: [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        )
        let archive = CabArchive.build(entries: [
            CabArchive.Entry(name: "messages.csv", data: Data(csv.utf8)),
            CabArchive.Entry(name: "messages.json", data: json)
        ])
        return try write(archive, named: "短信_\(DateText.stamp()).cab")
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
