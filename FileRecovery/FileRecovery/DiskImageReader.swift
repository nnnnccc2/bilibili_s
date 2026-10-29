import Foundation

/// 磁盘镜像读取器
/// 负责读取 .img 磁盘镜像文件，并提供按扇区/按字节偏移读取的能力
final class DiskImageReader {
    let url: URL
    let fileSize: UInt64
    private let handle: FileHandle

    init(url: URL) throws {
        self.url = url
        self.handle = try FileHandle(forReadingFrom: url)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        self.fileSize = attrs[.size] as? UInt64 ?? 0
    }

    deinit {
        try? handle.close()
    }

    /// 从指定偏移读取指定长度的数据
    func read(offset: UInt64, length: Int) throws -> Data {
        try handle.seek(toOffset: offset)
        return handle.readData(ofLength: length)
    }

    /// 读取前 N 个字节，通常用于文件系统签名检测
    func readFirst(_ length: Int) throws -> Data {
        try read(offset: 0, length: min(length, Int(fileSize)))
    }

    /// 按扇区读取（默认 512 字节）
    func readSector(_ index: UInt64, sectorSize: UInt64 = 512) throws -> Data {
        let offset = index * sectorSize
        return try read(offset: offset, length: Int(sectorSize))
    }
}

extension Data {
    /// 从指定偏移读取小端无符号整数
    func leUInt16(at offset: Int) -> UInt16? {
        guard offset + 2 <= count else { return nil }
        return withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return UInt16(p[offset]) | (UInt16(p[offset + 1]) << 8)
        }
    }

    func leUInt32(at offset: Int) -> UInt32? {
        guard offset + 4 <= count else { return nil }
        return withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return UInt32(p[offset]) | (UInt32(p[offset + 1]) << 8)
                | (UInt32(p[offset + 2]) << 16) | (UInt32(p[offset + 3]) << 24)
        }
    }

    func leUInt64(at offset: Int) -> UInt64? {
        guard offset + 8 <= count else { return nil }
        return withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
            var v: UInt64 = 0
            for i in 0..<8 { v |= UInt64(p[offset + i]) << (8 * i) }
            return v
        }
    }

    /// 从指定偏移读取大端无符号整数
    func beUInt16(at offset: Int) -> UInt16? {
        guard offset + 2 <= count else { return nil }
        return withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return (UInt16(p[offset]) << 8) | UInt16(p[offset + 1])
        }
    }

    func beUInt32(at offset: Int) -> UInt32? {
        guard offset + 4 <= count else { return nil }
        return withUnsafeBytes { raw in
            let p = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return (UInt32(p[offset]) << 24) | (UInt32(p[offset + 1]) << 16)
                | (UInt32(p[offset + 2]) << 8) | UInt32(p[offset + 3])
        }
    }

    /// 读取 ASCII 字符串（遇零或末尾截断）
    func asciiString(at offset: Int, length: Int) -> String? {
        guard offset < count else { return nil }
        let end = Swift.min(offset + length, count)
        let slice = self[offset..<end]
        guard let s = String(data: slice, encoding: .ascii) else { return nil }
        return s.trimmingCharacters(in: CharacterSet.controlCharacters)
            .trimmingCharacters(in: CharacterSet.whitespaces)
    }
}
