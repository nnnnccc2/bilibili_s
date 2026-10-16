//
//  LoginView.swift
//  BiliBili
//
//  Login page: QR code scan + SMS verification code
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import WebKit

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var onDismiss: (() -> Void)? = nil

    // MARK: - Tab
    @State private var selectedTab: LoginTab = .qr

    enum LoginTab: String, CaseIterable {
        case qr = "扫码登录"
        case sms = "手机号登录"
    }

    // MARK: - QR state
    @State private var qrCodeURL: String?
    @State private var qrKey: String?
    @State private var qrStatus: QRCodePollResult = .waiting
    @State private var qrError: String?
    @State private var isPolling = false
    private let pollTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    // MARK: - Phone login state
    @State private var webLoginError: String?
    @State private var isCompletingLogin = false

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
                    Button("取消") { if let onDismiss = onDismiss { onDismiss() } else { dismiss() } }
                        .foregroundColor(.biliBlue)
                }
            }
            .onAppear {
                if selectedTab == .qr { generateQR() }
            }
            .onReceive(pollTimer) { _ in
                guard isPolling, let key = qrKey else { return }
                poll(key: key)
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

    // MARK: - Phone / SMS login section
    //
    // Bilibili's SMS endpoints require a geetest captcha that can only be solved
    // inside a browser context, and the plain passport endpoints reject native
    // requests (-400). So phone + verification-code login is performed on
    // Bilibili's own login page inside a WKWebView; we harvest the session
    // cookies once the page signs the account in.

    private var smsLoginSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("在下方页面使用「短信登录」输入手机号与验证码，登录成功后会自动返回")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BiliWebLoginView(
                onCookies: { cookies in handleWebLoginCookies(cookies) },
                onError: { message in webLoginError = message }
            )
            .frame(height: 430)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.biliBorder, lineWidth: 1)
            )

            if isCompletingLogin {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在获取账号信息…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let error = webLoginError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("登录即表示同意《哔哩哔哩用户协议》和《隐私政策》")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
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
                                if let onDismiss = onDismiss { onDismiss() } else { dismiss() }
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

    // MARK: - Web login result

    /// Called once the web login page has signed the account in and its
    /// session cookies (SESSDATA / bili_jct / DedeUserID) were harvested.
    private func handleWebLoginCookies(_ cookies: [String: String]) {
        guard !isCompletingLogin else { return }
        webLoginError = nil
        isCompletingLogin = true
        BiliAPI.shared.setLoginCookies(cookies)
        store.loginAfterQRSuccess { ok in
            DispatchQueue.main.async {
                isCompletingLogin = false
                if ok {
                    if let onDismiss = onDismiss { onDismiss() } else { dismiss() }
                } else {
                    webLoginError = "登录成功但获取用户信息失败，请重试"
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

// MARK: - Bilibili web login (WKWebView)

/// Hosts Bilibili's official login page (二维码 / 手机号验证码, including the
/// geetest slider captcha) and reports the session cookies the moment the page
/// signs the account in. This is the only reliable SMS login path because the
/// native passport endpoints reject non-browser requests.
struct BiliWebLoginView: UIViewRepresentable {
    /// Called once SESSDATA is present in the cookie store.
    let onCookies: ([String: String]) -> Void
    /// Called when the page itself fails to load.
    let onError: (String) -> Void

    private static let harvestedNames: Set<String> = [
        "SESSDATA", "bili_jct", "DedeUserID", "DedeUserID__ckMd5", "sid"
    ]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Non-persistent store: the login session does not leak into other web views.
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // Mobile Safari UA so Bilibili serves its touch login page.
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        context.coordinator.webView = webView
        config.websiteDataStore.httpCookieStore.add(context.coordinator)
        if let url = URL(string: "https://passport.bilibili.com/login") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.websiteDataStore.httpCookieStore.remove(coordinator)
        uiView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        private let parent: BiliWebLoginView
        weak var webView: WKWebView?
        private var didFinish = false

        init(_ parent: BiliWebLoginView) { self.parent = parent }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            harvest(from: cookieStore)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            harvest(from: webView.configuration.websiteDataStore.httpCookieStore)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        private func report(_ error: Error) {
            let nsError = error as NSError
            // -999 cancellations happen on every redirect; ignore them.
            guard nsError.code != NSURLErrorCancelled else { return }
            DispatchQueue.main.async { self.parent.onError("无法加载登录页：\(nsError.localizedDescription)") }
        }

        private func harvest(from store: WKHTTPCookieStore) {
            guard !didFinish else { return }
            store.getAllCookies { [weak self] cookies in
                guard let self = self, !self.didFinish else { return }
                var dict: [String: String] = [:]
                for cookie in cookies where BiliWebLoginView.harvestedNames.contains(cookie.name) {
                    dict[cookie.name] = cookie.value
                }
                guard let sessData = dict["SESSDATA"], !sessData.isEmpty else { return }
                self.didFinish = true
                DispatchQueue.main.async { self.parent.onCookies(dict) }
            }
        }
    }
}
