import SwiftUI
import UIKit

/// 导出文件的系统分享面板。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// 待分享的导出文件。
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
