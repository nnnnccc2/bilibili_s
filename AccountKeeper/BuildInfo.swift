//
//  BuildInfo.swift
//  AccountKeeper
//
//  Build information (source time and compile time)
//

import Foundation

enum BuildInfo {
    /// Source code generation time (set at build)
    static let sourceTime = "2026-10-13 17:39:34 UTC"

    /// IPA compilation time (injected by CI, fallback shown if not set)
    static var compileTime: String {
        if let value = Bundle.main.infoDictionary?["BuildCompileTime"] as? String,
           !value.isEmpty, value != "BUILD_TIME_PLACEHOLDER" {
            return value
        }
        return "在 GitHub Actions 中编译时自动填入"
    }

    /// App version
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Build number
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
