# HelloWorld — iOS 18 SwiftUI 应用源码

一套可直接用 Xcode 打开、编译出可运行 iOS 18 应用的完整工程源码。

## 目录结构

```
helloworld/
├── HelloWorld.xcodeproj/
│   └── project.pbxproj          # Xcode 工程定义（iOS 18 / Swift 5）
└── HelloWorld/
    ├── HelloWorldApp.swift      # App 入口（@main）
    ├── ContentView.swift        # 主界面（SwiftUI）
    ├── Info.plist               # 应用配置
    └── Assets.xcassets/         # 图标与强调色资源
        ├── AppIcon.appiconset/
        └── AccentColor.colorset/
```

## 环境要求

| 项 | 要求 |
|---|---|
| 操作系统 | **macOS**（Xcode 只支持 macOS，本工程无法在 Linux/Windows 上编译） |
| 开发工具 | Xcode 16 或更高版本（内含 iOS 18 SDK） |
| Apple 开发者账号 | 真机安装需要签名；模拟器运行不需要付费账号 |

## 在 Mac 上编译出 IPA

### 方式一：Xcode 图形界面
1. 双击打开 `HelloWorld.xcodeproj`
2. 顶部选择运行目标（iPhone 模拟器，或连接的 iPhone）
3. `⌘R` 运行调试；`Product ▸ Archive` 归档后导出 IPA

### 方式二：命令行（推荐，可脚本化）

```bash
# 1. 打开模拟器运行（无需签名）
xcodebuild -project HelloWorld.xcodeproj -scheme HelloWorld \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# 2. 构建真机归档包（需配置签名）
xcodebuild -project HelloWorld.xcodeproj -scheme HelloWorld \
  -configuration Release -sdk iphoneos \
  -derivedDataPath build archive -archivePath build/HelloWorld.xcarchive

# 3. 从归档导出 .ipa（无开发者账号可加 -allowProvisioningUpdates 或选 development 方式）
xcodebuild -exportArchive -archivePath build/HelloWorld.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist
```

> `ExportOptions.plist` 示例（用 development 签名即可装到自己的 iPhone）：
> ```xml
> <?xml version="1.0" encoding="UTF-8"?>
> <plist version="1.0">
> <dict>
>   <key>method</key>
>   <string>development</string>
>   <key>signingStyle</key>
>   <string>automatic</string>
> </dict>
> </plist>
> ```

产物路径：`build/export/HelloWorld.ipa`

## 说明
- 部署目标 `IPHONEOS_DEPLOYMENT_TARGET = 18.0`，面向 iOS 18 及以上
- Bundle ID 默认 `com.example.HelloWorld`，可在 Xcode 中改为自己的
- 本机（Linux 沙箱）无 Xcode / iOS SDK，无法在此环境直接编译出 IPA；请在 macOS + Xcode 上按上文命令执行
