import SwiftUI
import UniformTypeIdentifiers

/// 主视图：导入磁盘镜像并展示已识别的文件系统列表
struct ContentView: View {
    @State private var images: [DiskImageInfo] = []
    @State private var showImporter = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if images.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(images) { info in
                            NavigationLink(destination: DiskDetailView(info: info)) {
                                imageRow(info)
                            }
                        }
                        .onDelete(perform: remove)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("磁盘恢复")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("导入镜像", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.data, .diskImage],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result: result)
            }
            .alert("导入失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 子视图

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("尚未导入磁盘镜像")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("点击右上角 + 导入 .img 分区文件，\n自动识别文件系统类型与详情")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showImporter = true
            } label: {
                Label("导入镜像文件", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private func imageRow(_ info: DiskImageInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconFor(info.fileSystem.type))
                    .foregroundStyle(.blue)
                Text(info.fileName)
                    .font(.headline)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text(info.fileSystem.type.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15), in: Capsule())
                Text(ByteCountFormatter.string(fromByteCount: Int64(info.fileSize), countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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

    // MARK: - 操作

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                // 获得安全访问权限
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "无法访问文件：\(url.lastPathComponent)"
                    continue
                }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let reader = try DiskImageReader(url: url)
                    let details = FileSystemDetector.detect(from: reader)
                    let info = DiskImageInfo(
                        url: url,
                        fileName: url.lastPathComponent,
                        fileSize: reader.fileSize,
                        fileSystem: details,
                        loadedAt: Date())
                    images.insert(info, at: 0)
                } catch {
                    errorMessage = "读取失败：\(error.localizedDescription)"
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func remove(at offsets: IndexSet) {
        images.remove(atOffsets: offsets)
    }
}
