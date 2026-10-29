import SwiftUI

/// 磁盘镜像详情视图：展示文件系统类型与详细参数
struct DiskDetailView: View {
    let info: DiskImageInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                overviewCard
                if !info.fileSystem.rawInfo.isEmpty {
                    rawInfoCard
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(info.fileName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 头部卡片

    private var headerCard: some View {
        HStack(spacing: 16) {
            Image(systemName: iconFor(info.fileSystem.type))
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    LinearGradient(colors: [.blue, .indigo], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(info.fileSystem.type.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                Text("文件大小：\(ByteCountFormatter.string(fromByteCount: Int64(info.fileSize)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("加载时间：\(info.loadedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - 概览卡片

    private var overviewCard: some View {
        VStack(spacing: 0) {
            if let label = info.fileSystem.volumeLabel, !label.isEmpty {
                row(title: "卷标", value: label)
            }
            if let serial = info.fileSystem.serialNumber, !serial.isEmpty {
                row(title: "序列号", value: serial)
            }
            if let total = info.fileSystem.totalBytes {
                row(title: "总容量", value: ByteCountFormatter.string(fromByteCount: Int64(total)))
            }
            if let free = info.fileSystem.freeBytes {
                row(title: "可用空间", value: ByteCountFormatter.string(fromByteCount: Int64(free)))
            }
            if let sector = info.fileSystem.sectorSize {
                row(title: "扇区大小", value: "\(sector) 字节")
            }
            if let cluster = info.fileSystem.clusterSize {
                row(title: "簇大小", value: "\(cluster) 字节")
            }
            if let clusters = info.fileSystem.totalClusters {
                row(title: "总簇数", value: "\(clusters)", last: true)
            } else if info.fileSystem.sectorSize != nil || info.fileSystem.volumeLabel != nil {
                EmptyView()
            }
        }
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - 原始信息卡片

    private var rawInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("详细信息")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                let keys = Array(info.fileSystem.rawInfo.keys).sorted()
                ForEach(keys.indices, id: \.self) { i in
                    let key = keys[i]
                    row(title: key, value: info.fileSystem.rawInfo[key] ?? "", last: i == keys.count - 1)
                }
            }
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
    }

    // MARK: - 通用行

    private func row(title: String, value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .leading)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            if !last {
                Divider().padding(.leading, 16)
            }
        }
    }

    private func iconFor(_ type: FileSystemType) -> String {
        switch type {
        case .fat12, .fat16, .fat32, .exfat: return "doc"
        case .ntfs: return "doc.text"
        case .ext2, .ext3, .ext4: return "terminal"
        case .hfs, .hfsPlus, .hfsx: return "apple.logo"
        case .apfs: return "cube"
        case .iso9660, .udf: return "opticaldisc"
        case .unknown: return "questionmark.disk"
        }
    }
}
