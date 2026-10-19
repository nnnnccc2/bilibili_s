import Foundation

/// 生成 Excel / Numbers 可直接打开的 `.xlsx`。
///
/// 采用最小化 OOXML：单元格用 `inlineStr` 直接内嵌文本，因此不需要共享字符串表。
enum Spreadsheet {
    static func makeXLSX(sheetName: String, rows: [[String]]) -> Data {
        ZipArchive.build(entries: [
            ZipArchive.Entry(name: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            ZipArchive.Entry(name: "_rels/.rels", data: Data(packageRelationships.utf8)),
            ZipArchive.Entry(name: "xl/workbook.xml", data: Data(workbook(sheetName: sheetName).utf8)),
            ZipArchive.Entry(name: "xl/_rels/workbook.xml.rels", data: Data(workbookRelationships.utf8)),
            ZipArchive.Entry(name: "xl/worksheets/sheet1.xml", data: Data(worksheet(rows: rows).utf8))
        ])
    }

    private static let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
        """

    private static let packageRelationships = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
        """

    private static let workbookRelationships = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
        """

    private static func workbook(sheetName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="\(escape(sheetName))" sheetId="1" r:id="rId1"/></sheets></workbook>
        """
    }

    private static func worksheet(rows: [[String]]) -> String {
        let body = rows.enumerated().map { rowIndex, cells -> String in
            let cellXML = cells.enumerated().map { cellIndex, text -> String in
                let reference = "\(columnName(cellIndex))\(rowIndex + 1)"
                return "<c r=\"\(reference)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(text))</t></is></c>"
            }.joined()
            return "<row r=\"\(rowIndex + 1)\">\(cellXML)</row>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\(body)</sheetData></worksheet>
        """
    }

    private static func columnName(_ index: Int) -> String {
        var value = index + 1
        var name = ""
        while value > 0 {
            let remainder = (value - 1) % 26
            name = String(UnicodeScalar(UInt8(65 + remainder))) + name
            value = (value - 1) / 26
        }
        return name
    }

    private static func escape(_ text: String) -> String {
        var result = ""
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            default: result.append(character)
            }
        }
        return result
    }
}
