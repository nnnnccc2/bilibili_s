# MiniBili Web

iOS 第三方哔哩哔哩客户端（WKWebView + 本地 HTML + 原生 scheme 代理）。
无弹幕功能，播放上限 720P（platform=html5 限制）。

## 本地构建
bash
brew install xcodegen
xcodegen generate
open MiniBiliWeb.xcodeproj   # Xcode 中 Cmd+R 直接跑模拟器/真机
