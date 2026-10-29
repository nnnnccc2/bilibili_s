import Foundation

/// 文件系统识别器
/// 通过读取磁盘镜像的引导扇区/超级块，识别文件系统类型并提取关键信息
enum FileSystemDetector {

    /// 主入口：从磁盘镜像识别文件系统
    static func detect(from reader: DiskImageReader) -> FileSystemDetails {
        let totalBytes = reader.fileSize

        do {
            // 读取第一个扇区（引导扇区），用于 FAT/exFAT/NTFS 检测
            let boot = try reader.read(offset: 0, length: 512)

            // 1. 检测 exFAT —— 偏移 3 处签名 "EXFAT   "
            if let sig = boot.asciiString(at: 3, length: 8), sig.hasPrefix("EXFAT") {
                return parseExFAT(boot: boot, totalBytes: totalBytes)
            }

            // 2. 检测 NTFS —— 偏移 3 处签名 "NTFS    "
            if let sig = boot.asciiString(at: 3, length: 8), sig.hasPrefix("NTFS") {
                return parseNTFS(boot: boot, totalBytes: totalBytes)
            }

            // 3. 检测 FAT12/16/32 —— 偏移 54 / 82 处 "FAT"
            if let fat32Sig = boot.asciiString(at: 82, length: 8), fat32Sig.hasPrefix("FAT32") {
                return parseFAT(boot: boot, variant: .fat32, totalBytes: totalBytes)
            }
            if let fat16Sig = boot.asciiString(at: 54, length: 8), fat16Sig.hasPrefix("FAT1") {
                return parseFAT(boot: boot, variant: .fat16, totalBytes: totalBytes)
            }
            // FAT12/16 没有 "FAT" 字符串时也通过 BPB 结构判断
            if looksLikeFAT(boot: boot) {
                return parseFAT(boot: boot, variant: nil, totalBytes: totalBytes)
            }

            // 4. 检测 HFS / HFS+ / HFSX —— 偏移 0 处签名
            if let sig = boot.asciiString(at: 0, length: 2) {
                switch sig {
                case "BD":
                    return parseHFS(boot: boot, variant: .hfs, totalBytes: totalBytes)
                case "H+":
                    return parseHFS(boot: boot, variant: .hfsPlus, totalBytes: totalBytes)
                case "HX":
                    return parseHFS(boot: boot, variant: .hfsx, totalBytes: totalBytes)
                default: break
                }
            }

            // 5. 检测 APFS —— 偏移 32 处签名 "NXSB"
            if totalBytes > 40 {
                let apfsBlock = try reader.read(offset: 0, length: 40)
                if let sig = apfsBlock.asciiString(at: 32, length: 4), sig == "NXSB" {
                    return parseAPFS(reader: reader, totalBytes: totalBytes)
                }
            }

            // 6. 检测 ISO 9660 —— 偏移 0x8001 处 "CD001"
            if totalBytes > 0x8006 {
                let isoBlock = try reader.read(offset: 0x8001, length: 6)
                if let sig = isoBlock.asciiString(at: 0, length: 5), sig == "CD001" {
                    return parseISO9660(reader: reader, totalBytes: totalBytes)
                }
            }

            // 7. 检测 UDF —— 偏移 0x8000 附近查找 "BEA01"/"NSR02"
            if totalBytes > 0x9000 {
                let udfArea = try reader.read(offset: 0x8000, length: 0x1000)
                if udfArea.contains("BEA01".data(using: .ascii)!) ||
                    udfArea.contains("NSR02".data(using: .ascii)!) ||
                    udfArea.contains("NSR03".data(using: .ascii)!) {
                    return FileSystemDetails(
                        type: .udf, volumeLabel: nil, serialNumber: nil,
                        totalBytes: totalBytes, freeBytes: nil,
                        clusterSize: nil, sectorSize: 2048, totalClusters: nil,
                        rawInfo: ["描述": "通用磁盘格式 (Universal Disk Format)"])
                }
            }

            // 8. 检测 ext2/3/4 —— 超级块在偏移 0x400，魔数 0xEF53 在偏移 0x438
            if totalBytes > 0x440 {
                let sb = try reader.read(offset: 0x400, length: 0x40)
                if let magic = sb.leUInt16(at: 0x38), magic == 0xEF53 {
                    return parseExt(reader: reader, totalBytes: totalBytes)
                }
            }

        } catch {
            return FileSystemDetails(
                type: .unknown, volumeLabel: nil, serialNumber: nil,
                totalBytes: totalBytes, freeBytes: nil,
                clusterSize: nil, sectorSize: nil, totalClusters: nil,
                rawInfo: ["错误": error.localizedDescription])
        }

        return FileSystemDetails(
            type: .unknown, volumeLabel: nil, serialNumber: nil,
            totalBytes: totalBytes, freeBytes: nil,
            clusterSize: nil, sectorSize: nil, totalClusters: nil,
            rawInfo: ["描述": "未识别的文件系统"])
    }

    // MARK: - FAT12/16/32

    private static func looksLikeFAT(boot: Data) -> Bool {
        // 引导扇区以 0x55 0xAA 结束
        guard boot.count >= 512 else { return false }
        guard boot[510] == 0x55, boot[511] == 0xAA else { return false }
        // 每扇区字节数应为 512 的常见值
        guard let bps = boot.leUInt16(at: 11), bps == 512 || bps == 1024 || bps == 2048 || bps == 4096 else {
            return false
        }
        // 每簇扇区数应为 2 的幂
        guard let spc = boot[safe: 13], spc > 0, (spc & (spc - 1)) == 0 else { return false }
        return true
    }

    private static func parseFAT(boot: Data, variant: FileSystemType?, totalBytes: UInt64) -> FileSystemDetails {
        let sectorSize = boot.leUInt16(at: 11) ?? 512
        let sectorsPerCluster = boot[13]
        let reservedSectors = boot.leUInt16(at: 14) ?? 0
        let numberOfFATs = boot[16]
        let rootEntries = boot.leUInt16(at: 17) ?? 0
        let totalSectors16 = boot.leUInt16(at: 19) ?? 0
        let sectorsPerFAT16 = boot.leUInt16(at: 22) ?? 0
        let totalSectors32 = boot.leUInt32(at: 32) ?? 0
        let sectorsPerFAT32 = boot.leUInt32(at: 36) ?? 0
        let volumeSerial = boot.leUInt32(at: variant == .fat32 ? 67 : 39)

        let totalSectors = totalSectors16 > 0 ? UInt64(totalSectors16) : UInt64(totalSectors32)
        let sectorsPerFAT = sectorsPerFAT16 > 0 ? UInt64(sectorsPerFAT16) : UInt64(sectorsPerFAT32)

        // 判断 FAT 版本
        let fsType: FileSystemType
        if variant == .fat32 {
            fsType = .fat32
        } else if totalSectors == 0 {
            fsType = .fat12
        } else {
            // 根据簇数量判断
            let rootDirSectors = (UInt64(rootEntries) * 32 + UInt64(sectorSize) - 1) / UInt64(sectorSize)
            let dataSectors = totalSectors - (UInt64(reservedSectors) + UInt64(numberOfFATs) * sectorsPerFAT + rootDirSectors)
            let clustersPerFAT = sectorsPerFAT * UInt64(sectorSize) / 2
            let totalClusters = dataSectors / UInt64(sectorsPerCluster)
            if totalClusters < 4085 {
                fsType = .fat12
            } else if totalClusters < 65525 {
                fsType = .fat16
            } else {
                fsType = .fat32
            }
        }

        var rawInfo: [String: String] = [
            "每扇区字节数": "\(sectorSize)",
            "每簇扇区数": "\(sectorsPerCluster)",
            "保留扇区数": "\(reservedSectors)",
            "FAT 表数量": "\(numberOfFATs)",
            "根目录项数": "\(rootEntries)",
            "每 FAT 扇区数": "\(sectorsPerFAT)",
        ]

        return FileSystemDetails(
            type: fsType,
            volumeLabel: boot.asciiString(at: variant == .fat32 ? 71 : 43, length: 11),
            serialNumber: volumeSerial.map { String(format: "%08X", $0) },
            totalBytes: totalBytes,
            freeBytes: nil,
            clusterSize: UInt32(sectorsPerCluster) * UInt32(sectorSize),
            sectorSize: UInt32(sectorSize),
            totalClusters: totalSectors / UInt64(sectorsPerCluster),
            rawInfo: rawInfo)
    }

    // MARK: - exFAT

    private static func parseExFAT(boot: Data, totalBytes: UInt64) -> FileSystemDetails {
        let sectorSizeShift = boot[64]
        let sectorsPerClusterShift = boot[69]
        let sectorSize: UInt32 = 1 << sectorSizeShift
        let clusterSize: UInt32 = sectorSize << sectorsPerClusterShift
        let totalSectors = boot.leUInt64(at: 40) ?? 0
        let clustersPerFAT = boot.leUInt32(at: 52) ?? 0
        let volumeSerial = boot.leUInt32(at: 100)

        return FileSystemDetails(
            type: .exfat,
            volumeLabel: nil,
            serialNumber: volumeSerial.map { String(format: "%08X", $0) },
            totalBytes: totalSectors > 0 ? totalSectors * UInt64(sectorSize) : totalBytes,
            freeBytes: nil,
            clusterSize: clusterSize,
            sectorSize: sectorSize,
            totalClusters: UInt64(clustersPerFAT),
            rawInfo: [
                "每扇区字节数": "\(sectorSize)",
                "每簇扇区数": "\(1 << sectorsPerClusterShift)",
                "总扇区数": "\(totalSectors)",
                "FAT 起始扇区": "\(boot.leUInt32(at: 48) ?? 0)",
                "簇堆起始扇区": "\(boot.leUInt32(at: 56) ?? 0)",
                "簇数量": "\(clustersPerFAT)",
            ])
    }

    // MARK: - NTFS

    private static func parseNTFS(boot: Data, totalBytes: UInt64) -> FileSystemDetails {
        let sectorSize = boot.leUInt16(at: 11) ?? 512
        let sectorsPerCluster = Int8(bitPattern: boot[13])
        let totalSectors = boot.leUInt64(at: 40) ?? 0
        let mftCluster = boot.leUInt64(at: 48) ?? 0
        let volumeSerial = boot.leUInt64(at: 72)

        let clusterSize: UInt32
        if sectorsPerCluster > 0 {
            clusterSize = UInt32(sectorSize) * UInt32(sectorsPerCluster)
        } else {
            // 负值表示 2 的幂次方字节
            clusterSize = 1 << UInt32(-sectorsPerCluster)
        }

        return FileSystemDetails(
            type: .ntfs,
            volumeLabel: nil,
            serialNumber: volumeSerial.map { String(format: "%016X", $0) },
            totalBytes: totalSectors > 0 ? totalSectors * UInt64(sectorSize) : totalBytes,
            freeBytes: nil,
            clusterSize: clusterSize,
            sectorSize: UInt32(sectorSize),
            totalClusters: totalSectors > 0 ? totalSectors / UInt64(sectorsPerCluster > 0 ? sectorsPerCluster : 1) : nil,
            rawInfo: [
                "每扇区字节数": "\(sectorSize)",
                "每簇扇区数": "\(sectorsPerCluster)",
                "总扇区数": "\(totalSectors)",
                "MFT 起始簇": "\(mftCluster)",
                "MFTMirr 起始簇": "\(boot.leUInt64(at: 56) ?? 0)",
            ])
    }

    // MARK: - HFS / HFS+ / HFSX

    private static func parseHFS(boot: Data, variant: FileSystemType, totalBytes: UInt64) -> FileSystemDetails {
        // HFS+ 签名 H+，版本 4；HFSX 签名 HX
        let version = boot.beUInt16(at: 2) ?? 0
        let totalSectors = boot.beUInt32(at: 40) ?? 0
        let sectorSize = boot.beUInt32(at: 44) ?? 512
        let freeSectors = boot.beUInt32(at: 48) ?? 0
        let nextAllocation = boot.beUInt32(at: 52) ?? 0
        let clumpSize = boot.beUInt32(at: 56) ?? 0
        let volumeSerial = boot.beUInt32(at: 12)

        return FileSystemDetails(
            type: variant,
            volumeLabel: nil,
            serialNumber: volumeSerial.map { String(format: "%08X", $0) },
            totalBytes: totalSectors > 0 ? UInt64(totalSectors) * UInt64(sectorSize) : totalBytes,
            freeBytes: UInt64(freeSectors) * UInt64(sectorSize),
            clusterSize: clumpSize,
            sectorSize: sectorSize,
            totalClusters: totalSectors > 0 ? UInt64(totalSectors) : nil,
            rawInfo: [
                "版本": "\(version)",
                "每扇区字节数": "\(sectorSize)",
                "总扇区数": "\(totalSectors)",
                "空闲扇区数": "\(freeSectors)",
                "下一分配块": "\(nextAllocation)",
                "聚簇大小": "\(clumpSize)",
            ])
    }

    // MARK: - APFS

    private static func parseAPFS(reader: DiskImageReader, totalBytes: UInt64) -> FileSystemDetails {
        // APFS 容器超级块（NXSuperBlock）偏移 32 处为魔数 NXSB
        // 容器超级块扇区大小在偏移 48
        var rawInfo: [String: String] = [:]
        do {
            let block = try reader.read(offset: 0, length: 200)
            let blockSize = block.leUInt32(at: 48) ?? 4096
            let totalBlocks = block.leUInt64(at: 56) ?? 0
            let freeBlocks = block.leUInt64(at: 64) ?? 0

            rawInfo["块大小"] = "\(blockSize)"
            rawInfo["总块数"] = "\(totalBlocks)"
            rawInfo["空闲块数"] = "\(freeBlocks)"
            rawInfo["容器容量"] = ByteCountFormatter.string(fromByteCount: Int64(totalBlocks * UInt64(blockSize)))
            rawInfo["可用空间"] = ByteCountFormatter.string(fromByteCount: Int64(freeBlocks * UInt64(blockSize)))

            return FileSystemDetails(
                type: .apfs, volumeLabel: nil, serialNumber: nil,
                totalBytes: totalBlocks * UInt64(blockSize),
                freeBytes: freeBlocks * UInt64(blockSize),
                clusterSize: blockSize, sectorSize: blockSize,
                totalClusters: totalBlocks,
                rawInfo: rawInfo)
        } catch {
            rawInfo["错误"] = error.localizedDescription
            return FileSystemDetails(
                type: .apfs, volumeLabel: nil, serialNumber: nil,
                totalBytes: totalBytes, freeBytes: nil,
                clusterSize: nil, sectorSize: nil, totalClusters: nil,
                rawInfo: rawInfo)
        }
    }

    // MARK: - ISO 9660

    private static func parseISO9660(reader: DiskImageReader, totalBytes: UInt64) -> FileSystemDetails {
        var rawInfo: [String: String] = [:]
        do {
            // PVD 在扇区 16，偏移 0x8000
            let pvd = try reader.read(offset: 0x8000, length: 2048)
            let volumeIdentifier = pvd.asciiString(at: 40, length: 32)
            let volumeSetSize = pvd.leUInt16(at: 120) ?? 1
            let volumeSeqNumber = pvd.leUInt16(at: 124) ?? 1
            let logicalBlockSize = pvd.leUInt16(at: 128) ?? 2048
            let volumeSpaceSize = pvd.leUInt32(at: 80) ?? 0

            rawInfo["卷标识符"] = volumeIdentifier ?? "(无)"
            rawInfo["卷集大小"] = "\(volumeSetSize)"
            rawInfo["卷序列号"] = "\(volumeSeqNumber)"
            rawInfo["逻辑块大小"] = "\(logicalBlockSize)"
            rawInfo["卷空间大小"] = "\(volumeSpaceSize) 块"

            return FileSystemDetails(
                type: .iso9660,
                volumeLabel: volumeIdentifier,
                serialNumber: pvd.asciiString(at: 12, length: 32)?.trimmingCharacters(in: CharacterSet.whitespaces),
                totalBytes: UInt64(volumeSpaceSize) * UInt64(logicalBlockSize),
                freeBytes: nil,
                clusterSize: UInt32(logicalBlockSize),
                sectorSize: 2048,
                totalClusters: UInt64(volumeSpaceSize),
                rawInfo: rawInfo)
        } catch {
            rawInfo["错误"] = error.localizedDescription
            return FileSystemDetails(
                type: .iso9660, volumeLabel: nil, serialNumber: nil,
                totalBytes: totalBytes, freeBytes: nil,
                clusterSize: nil, sectorSize: 2048, totalClusters: nil,
                rawInfo: rawInfo)
        }
    }

    // MARK: - ext2/3/4

    private static func parseExt(reader: DiskImageReader, totalBytes: UInt64) -> FileSystemDetails {
        var rawInfo: [String: String] = [:]
        do {
            let sb = try reader.read(offset: 0x400, length: 256)
            let inodesCount = sb.leUInt32(at: 0) ?? 0
            let blocksCount = sb.leUInt32(at: 4) ?? 0
            let reservedBlocks = sb.leUInt32(at: 8) ?? 0
            let freeBlocks = sb.leUInt32(at: 12) ?? 0
            let freeInodes = sb.leUInt32(at: 16) ?? 0
            let firstDataBlock = sb.leUInt32(at: 20) ?? 0
            let logBlockSize = sb.leUInt32(at: 24) ?? 0
            let blockSize: UInt32 = 1024 << logBlockSize
            let blocksPerGroup = sb.leUInt32(at: 32) ?? 0
            let inodesPerGroup = sb.leUInt32(at: 40) ?? 0
            let magic = sb.leUInt16(at: 56) ?? 0
            let inodeSize = sb.leUInt16(at: 88) ?? 128

            // 区分 ext2/3/4 需查看特性兼容标志
            let featCompat = sb.leUInt32(at: 92) ?? 0
            let featIncompat = sb.leUInt32(at: 96) ?? 0
            let featRoCompat = sb.leUInt32(at: 100) ?? 0

            // ext4: 支持 extents (0x40) 或 64 位 (0x80) 不兼容特性
            // ext3: 拥有日志特性 (compat 0x04)
            var fsType: FileSystemType = .ext2
            if featIncompat & 0x40 != 0 || featIncompat & 0x80 != 0 {
                fsType = .ext4
            } else if featCompat & 0x04 != 0 {
                fsType = .ext3
            }

            rawInfo["魔数"] = String(format: "0x%04X", magic)
            rawInfo["块大小"] = "\(blockSize) 字节"
            rawInfo["总块数"] = "\(blocksCount)"
            rawInfo["空闲块数"] = "\(freeBlocks)"
            rawInfo["保留块数"] = "\(reservedBlocks)"
            rawInfo["inode 总数"] = "\(inodesCount)"
            rawInfo["空闲 inode"] = "\(freeInodes)"
            rawInfo["每块组块数"] = "\(blocksPerGroup)"
            rawInfo["每块组 inode"] = "\(inodesPerGroup)"
            rawInfo["inode 大小"] = "\(inodeSize)"
            rawInfo["第一数据块"] = "\(firstDataBlock)"
            rawInfo["兼容特性"] = String(format: "0x%08X", featCompat)
            rawInfo["不兼容特性"] = String(format: "0x%08X", featIncompat)
            rawInfo["只读兼容特性"] = String(format: "0x%08X", featRoCompat)

            let volumeUUID = sb.subdata(in: 104..<120).map { String(format: "%02X", $0) }.joined()

            return FileSystemDetails(
                type: fsType,
                volumeLabel: sb.asciiString(at: 120, length: 16),
                serialNumber: volumeUUID,
                totalBytes: UInt64(blocksCount) * UInt64(blockSize),
                freeBytes: UInt64(freeBlocks) * UInt64(blockSize),
                clusterSize: blockSize,
                sectorSize: 512,
                totalClusters: UInt64(blocksCount),
                rawInfo: rawInfo)
        } catch {
            rawInfo["错误"] = error.localizedDescription
            return FileSystemDetails(
                type: .ext2, volumeLabel: nil, serialNumber: nil,
                totalBytes: totalBytes, freeBytes: nil,
                clusterSize: nil, sectorSize: 512, totalClusters: nil,
                rawInfo: rawInfo)
        }
    }
}

private extension Data {
    subscript(safe index: Int) -> UInt8? {
        guard index < count else { return nil }
        return self[index]
    }
}
