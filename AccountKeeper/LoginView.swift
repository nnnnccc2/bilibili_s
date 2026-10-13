//
//  LoginView.swift
//  BiliBili
//
//  QR code login using Bilibili passport API
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var qrCodeURL: String?
    @State private var qrKey: String?
    @State private var status: QRCodePollResult = .waiting
    @State private var errorMessage: String?
    @State private var isPolling = false

    private let pollTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.pink.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Text("B")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundStyle(Color.pink)
                        }
                        Text("BiliBili")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("使用哔哩哔哩 App 扫码登录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // QR code
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                            .frame(width: 240, height: 240)

                        if status == .expired {
                            VStack(spacing: 12) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("二维码已过期")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button("点击刷新") {
                                    generateQR()
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(Color.pink)
                                .clipShape(Capsule())
                            }
                        } else if let qr = qrCodeURL, let image = generateQRImage(from: qr) {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                        } else {
                            ProgressView()
                                .scaleEffect(1.2)
                        }
                    }
                    .frame(width: 240, height: 240)

                    // Status text
                    statusText
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                generateQR()
            }
            .onReceive(pollTimer) { _ in
                guard isPolling, let key = qrKey else { return }
                poll(key: key)
            }
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .waiting:
            Text("请打开哔哩哔哩 App 扫描二维码")
        case .scanned:
            Text("扫描成功，请在手机上确认登录")
                .foregroundStyle(.green)
        case .expired:
            Text("二维码已过期，请刷新重试")
                .foregroundStyle(.red)
        case .error:
            Text("登录出错，请重试")
                .foregroundStyle(.red)
        case .success:
            Text("登录成功")
                .foregroundStyle(.green)
        }
    }

    // MARK: - QR generation & polling

    private func generateQR() {
        errorMessage = nil
        status = .waiting
        qrCodeURL = nil
        isPolling = false
        BiliAPI.shared.generateQRCode { result in
            DispatchQueue.main.async {
                guard let result = result else {
                    self.errorMessage = "获取二维码失败，请检查网络"
                    return
                }
                self.qrCodeURL = result.url
                self.qrKey = result.key
                self.isPolling = true
            }
        }
    }

    private func poll(key: String) {
        BiliAPI.shared.pollQRCode(key: key) { result in
            DispatchQueue.main.async {
                self.status = result
                switch result {
                case .success:
                    self.isPolling = false
                    self.store.loginAfterQRSuccess { ok in
                        DispatchQueue.main.async {
                            if ok {
                                dismiss()
                            } else {
                                self.errorMessage = "登录成功但获取用户信息失败，请重试"
                            }
                        }
                    }
                case .expired, .error:
                    self.isPolling = false
                case .waiting, .scanned:
                    break
                }
            }
        }
    }

    // MARK: - QR image generator

    private func generateQRImage(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    LoginView()
        .environmentObject(AppStore())
}
