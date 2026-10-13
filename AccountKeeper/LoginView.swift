//
//  LoginView.swift
//  BiliBili
//
//  Login page: QR code scan + SMS verification code
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    // MARK: - Tab
    @State private var selectedTab: LoginTab = .qr

    enum LoginTab: String, CaseIterable {
        case qr = "扫码登录"
        case sms = "验证码登录"
    }

    // MARK: - QR state
    @State private var qrCodeURL: String?
    @State private var qrKey: String?
    @State private var qrStatus: QRCodePollResult = .waiting
    @State private var qrError: String?
    @State private var isPolling = false
    private let pollTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    // MARK: - SMS state
    @State private var phone: String = ""
    @State private var smsCode: String = ""
    @State private var smsError: String?
    @State private var isSendingCode = false
    @State private var isLoggingIn = false
    @State private var countdown: Int = 0
    private let countdownTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                biliBackgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.biliBlue.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                Text("B")
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundStyle(Color.biliBlue)
                            }
                            Text("BiliBili")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("登录以同步观看历史与收藏")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)

                        // Tab switcher
                        HStack(spacing: 0) {
                            ForEach(LoginTab.allCases, id: \.self) { tab in
                                Button {
                                    selectedTab = tab
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(tab.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(selectedTab == tab ? .bold : .regular)
                                            .foregroundStyle(selectedTab == tab ? Color.biliBlue : .secondary)
                                        Capsule()
                                            .fill(selectedTab == tab ? Color.biliBlue : Color.clear)
                                            .frame(height: 3)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(.horizontal, 40)

                        // Content
                        if selectedTab == .qr {
                            qrLoginSection
                        } else {
                            smsLoginSection
                        }

                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.biliBlue)
                }
            }
            .onAppear {
                if selectedTab == .qr { generateQR() }
            }
            .onReceive(pollTimer) { _ in
                guard isPolling, let key = qrKey else { return }
                poll(key: key)
            }
            .onReceive(countdownTimer) { _ in
                if countdown > 0 { countdown -= 1 }
            }
        }
    }

    // MARK: - QR login section

    @ViewBuilder
    private var qrLoginSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                    .frame(width: 240, height: 240)

                if qrStatus == .expired {
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
                        .background(Color.biliBlue)
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

            qrStatusText
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let error = qrError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var qrStatusText: some View {
        switch qrStatus {
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

    // MARK: - SMS login section

    private var smsLoginSection: some View {
        VStack(spacing: 16) {
            // Phone input
            HStack {
                Text("+86")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                TextField("请输入手机号", text: $phone)
                    .keyboardType(.numberPad)
                    .onChange(of: phone) { _, newValue in
                        phone = String(newValue.prefix(11)).filter { $0.isNumber }
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Code input + send button
            HStack {
                TextField("请输入验证码", text: $smsCode)
                    .keyboardType(.numberPad)
                    .onChange(of: smsCode) { _, newValue in
                        smsCode = String(newValue.prefix(6)).filter { $0.isNumber }
                    }
                Button {
                    sendCode()
                } label: {
                    Text(countdown > 0 ? "\(countdown)s 后重发" : "获取验证码")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(countdown > 0 || phone.count != 11 ? .secondary : .biliBlue)
                }
                .disabled(countdown > 0 || phone.count != 11 || isSendingCode)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if let error = smsError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Login button
            Button {
                loginWithSMS()
            } label: {
                HStack {
                    if isLoggingIn {
                        ProgressView().tint(.white)
                    }
                    Text("登录")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(phone.count == 11 && smsCode.count == 6 ? Color.biliBlue : Color.biliBlue.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(phone.count != 11 || smsCode.count != 6 || isLoggingIn)

            Text("登录即表示同意《哔哩哔哩用户协议》和《隐私政策》")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - QR generation & polling

    private func generateQR() {
        qrError = nil
        qrStatus = .waiting
        qrCodeURL = nil
        isPolling = false
        BiliAPI.shared.generateQRCode { result in
            DispatchQueue.main.async {
                guard let result = result else {
                    self.qrError = "获取二维码失败，请检查网络"
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
                self.qrStatus = result
                switch result {
                case .success:
                    self.isPolling = false
                    self.store.loginAfterQRSuccess { ok in
                        DispatchQueue.main.async {
                            if ok {
                                dismiss()
                            } else {
                                self.qrError = "登录成功但获取用户信息失败，请重试"
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

    // MARK: - SMS actions

    private func sendCode() {
        guard phone.count == 11 else {
            smsError = "请输入正确的手机号"
            return
        }
        smsError = nil
        isSendingCode = true
        BiliAPI.shared.sendSMSCode(phone: phone) { success, msg in
            DispatchQueue.main.async {
                isSendingCode = false
                if success {
                    countdown = 60
                } else {
                    smsError = msg ?? "验证码发送失败"
                }
            }
        }
    }

    private func loginWithSMS() {
        guard phone.count == 11, smsCode.count == 6 else { return }
        smsError = nil
        isLoggingIn = true
        BiliAPI.shared.loginWithSMS(phone: phone, code: smsCode) { [weak self] success, msg in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoggingIn = false
                if success {
                    self.store.loginAfterQRSuccess { ok in
                        DispatchQueue.main.async {
                            if ok {
                                dismiss()
                            } else {
                                self.smsError = "登录成功但获取用户信息失败，请重试"
                            }
                        }
                    }
                } else {
                    self.smsError = msg ?? "登录失败，请检查验证码"
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
