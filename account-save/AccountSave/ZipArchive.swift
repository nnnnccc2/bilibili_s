import Foundation

/// 极简 ZIP 容器写入器：条目以「存储（不压缩）」方式写入。
///
/// 用于生成 `.xlsx` 这类本质上就是 ZIP 的文件，无需任何第三方库。
enum ZipArchive {
    struct Entry {
        let name: String
        let data: Data
    }

    static func build(entries: [Entry]) -> Data {
        var archive = Data()
        var directory = Data()
        let stamp = dosDateTime()

        for entry in entries {
            let nameBytes = Array(entry.name.utf8)
            let checksum = crc32(entry.data)
            let size = UInt32(entry.data.count)
            let offset = UInt32(archive.count)

            // 本地文件头
            archive.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
            archive.append(littleEndian: UInt16(20))
            archive.append(littleEndian: UInt16(0x0800))
            archive.append(littleEndian: UInt16(0))
            archive.append(littleEndian: stamp.time)
            archive.append(littleEndian: stamp.date)
            archive.append(littleEndian: checksum)
            archive.append(littleEndian: size)
            archive.append(littleEndian: size)
            archive.append(littleEndian: UInt16(nameBytes.count))
            archive.append(littleEndian: UInt16(0))
            archive.append(contentsOf: nameBytes)
            archive.append(entry.data)

            // 中央目录记录
            directory.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            directory.append(littleEndian: UInt16(20))
            directory.append(littleEndian: UInt16(20))
            directory.append(littleEndian: UInt16(0x0800))
            directory.append(littleEndian: UInt16(0))
            directory.append(littleEndian: stamp.time)
            directory.append(littleEndian: stamp.date)
            directory.append(littleEndian: checksum)
            directory.append(littleEndian: size)
            directory.append(littleEndian: size)
            directory.append(littleEndian: UInt16(nameBytes.count))
            directory.append(littleEndian: UInt16(0))
            directory.append(littleEndian: UInt16(0))
            directory.append(littleEndian: UInt16(0))
            directory.append(littleEndian: UInt16(0))
            directory.append(littleEndian: UInt32(0))
            directory.append(littleEndian: offset)
            directory.append(contentsOf: nameBytes)
        }

        let directoryOffset = UInt32(archive.count)
        let directorySize = UInt32(directory.count)
        archive.append(directory)

        // 中央目录结束记录
        archive.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        archive.append(littleEndian: UInt16(0))
        archive.append(littleEndian: UInt16(0))
        archive.append(littleEndian: UInt16(entries.count))
        archive.append(littleEndian: UInt16(entries.count))
        archive.append(littleEndian: directorySize)
        archive.append(littleEndian: directoryOffset)
        archive.append(littleEndian: UInt16(0))
        return archive
    }

    static func crc32(_ data: Data) -> UInt32 {
        var value: UInt32 = 0xFFFF_FFFF
        for byte in data {
            value = crcTable[Int((value ^ UInt32(byte)) & 0xFF)] ^ (value >> 8)
        }
        return value ^ 0xFFFF_FFFF
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) == 1 ? (0xEDB8_8320 ^ (value >> 1)) : (value >> 1)
        }
        return value
    }

    /// ZIP 使用的 MS-DOS 日期时间格式。
    private static func dosDateTime(_ date: Date = Date()) -> (time: UInt16, date: UInt16) {
        let parts = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = UInt16(max(1980, parts.year ?? 1980) - 1980)
        let month = UInt16(parts.month ?? 1)
        let day = UInt16(parts.day ?? 1)
        let hour = UInt16(parts.hour ?? 0)
        let minute = UInt16(parts.minute ?? 0)
        let second = UInt16(parts.second ?? 0)

        let dosDate = year << 9 | month << 5 | day
        let dosTime = hour << 11 | minute << 5 | second / 2
        return (dosTime, dosDate)
    }
}

private extension Data {
    mutating func append(littleEndian value: UInt16) {
        append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)])
    }

    mutating func append(littleEndian value: UInt32) {
        append(contentsOf: [
            UInt8(value & 0xFF),
            UInt8(value >> 8 & 0xFF),
            UInt8(value >> 16 & 0xFF),
            UInt8(value >> 24 & 0xFF)
        ])
    }
}
