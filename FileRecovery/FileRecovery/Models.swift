import Foundation

/// 支持的文件系统类型
enum FileSystemType: String, CaseIterable, Identifiable {
    case unknown = "未知"
    case fat12 = "FAT12"
    case fat16 = "FAT16"
    case fat32 = "FAT32"
    case exfat = "exFAT"
    case ntfs = "NTFS"
    case ext2 = "ext2"
    case ext3 = "ext3"
    case ext4 = "ext4"
    case hfs = "HFS"
    case hfsPlus = "HFS+"
    case hfsx = "HFSX"
    case apfs = "APFS"
    case iso9660 = "ISO 9660"
    case udf = "UDF"

    var id: String { rawValue }
}

/// 文件系统详情
struct FileSystemDetails {
    let type: FileSystemType
    let volumeLabel: String?
    let serialNumber: String?
    let totalBytes: UInt64?
    let freeBytes: UInt64?
    let clusterSize: UInt32?
    let sectorSize: UInt32?
    let totalClusters: UInt64?
    let rawInfo: [String: String]
}

/// 磁盘镜像信息
struct DiskImageInfo: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let fileSize: UInt64
    let fileSystem: FileSystemDetails
    let loadedAt: Date
}
