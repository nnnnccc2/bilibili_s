//
//  LoginView.swift
//  BiliBili
//
//  Login page: phone + SMS code, and account/password
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var loginMode: LoginMode = .sms
    @State private var phone: String = ""
    @State private var code: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var countdown: Int = 0
    @State private var showError: String? = nil

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum LoginMode {
        case sms, password
    }

    private var isValidPhone: Bool {
        phone.count == 11 && phone.allSatisfy { $0.isNumber }
    }

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
                        Text("纯净观影，自动净化低质内容")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // Mode toggle
                    Picker("登录方式", selection: $loginMode) {
                        Text("验证码登录").tag(LoginMode.sms)
                        Text("密码登录").tag(LoginMode.password)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if loginMode == .sms {
                        smsLoginSection
                    } else {
                        passwordLoginSection
                    }

                    if let error = showError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
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
            .onReceive(timer) { _ in
                if countdown > 0 {
                    countdown -= 1
                }
            }
        }
    }

    // MARK: - SMS login

    private var smsLoginSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("+86")
                    .foregroundStyle(.secondary)
                Divider()
                    .frame(height: 24)
                TextField("请输入手机号", text: $phone)
                    .keyboardType(.numberPad)
                    .onChange(of: phone) { _, newValue in
                        phone = String(newValue.filter { $0.isNumber }.prefix(11))
                    }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)

            HStack {
                TextField("请输入验证码", text: $code)
                    .keyboardType(.numberPad)
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter { $0.isNumber }.prefix(6))
                    }

                Button {
                    sendCode()
                } label: {
                    Text(countdown > 0 ? "\(countdown)s 后重发" : "获取验证码")
                        .fontWeight(.medium)
                        .foregroundStyle(countdown > 0 ? .secondary : (isValidPhone ? Color.pink : .secondary))
                }
                .disabled(countdown > 0 || !isValidPhone)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)

            Button {
                doSmsLogin()
            } label: {
                Text("登录")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isValidPhone && code.count == 6 ? Color.pink : Color.pink.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!isValidPhone || code.count != 6)
            .padding(.horizontal)
        }
    }

    // MARK: - Password login

    private var passwordLoginSection: some View {
        VStack(spacing: 16) {
            TextField("账号 / 手机号", text: $username)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

            SecureField("密码", text: $password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

            Button {
                doPasswordLogin()
            } label: {
                Text("登录")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(!username.isEmpty && !password.isEmpty ? Color.pink : Color.pink.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(username.isEmpty || password.isEmpty)
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func sendCode() {
        guard isValidPhone else {
            showError = "请输入正确的手机号"
            return
        }
        showError = nil
        // Simulate sending SMS code
        countdown = 60
    }

    private func doSmsLogin() {
        guard isValidPhone else {
            showError = "请输入正确的手机号"
            return
        }
        guard code.count == 6 else {
            showError = "请输入 6 位验证码"
            return
        }
        store.login(phone: phone, code: code)
        dismiss()
    }

    private func doPasswordLogin() {
        guard !username.isEmpty, !password.isEmpty else { return }
        store.login(username: username, password: password)
        dismiss()
    }
}

#Preview {
    LoginView()
        .environmentObject(AppStore())
}
