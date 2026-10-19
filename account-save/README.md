# 账号保存（短信收纳盒）

iOS 18 本地短信收纳 App：短信不会由 App 主动读取（iOS 不允许），而是由「快捷指令」在收到短信时把
**发件人 + 短信内容** 交给 App，运行时的弹窗再输入**账号名**，这条短信就保存到对应账号条目下。

## 功能

- 快捷指令动作「导入商家短信」：保存短信发件人、短信内容到指定账号；账号不存在时自动新建
- 「账号名」设为「每次询问」时，自动化运行会弹窗输入账号名
- 首页「短信收纳盒」：搜索短信或账号，按最近短信时间排序，支持删除
- 账号详情：账号名、注册手机号、号码数 / 短信数，短信列表按时间倒序，自动识别验证码并一键复制
- 账号维护：新建账号、编辑账号名与注册手机号（接收短信的手机号）
- 导出账号（表格）：CSV 文件，列为 `账号名,注册手机号`
- 导出短信（.cab）：标准 ZIP 容器（`.cab` 后缀），内含 `messages.csv` 与 `messages.json`
- 无「凭证」功能，无任何网络请求，数据全部保存在本机

## 目录结构

```
account-save/
├── AccountSave.xcodeproj          # Xcode 工程（共享 AccountSave scheme）
└── AccountSave/
    ├── AccountSaveApp.swift       # App 入口，注入本地数据库
    ├── Models.swift               # Account / SMSMessage 模型
    ├── Storage.swift              # 本地数据库与短信写入逻辑
    ├── ImportMerchantSMSIntent.swift  # 快捷指令动作「导入商家短信」
    ├── TextUtils.swift            # 验证码识别与时间格式化
    ├── MerchantIcon.swift         # 账号图标（底色 + 缩写）
    ├── CabArchive.swift           # .cab 归档写入（ZIP 存储方式）
    ├── ExportService.swift        # 导出账号表格 / 导出短信
    ├── SMSInboxView.swift         # 短信收纳盒（首页）
    ├── AccountDetailView.swift    # 账号详情
    ├── AccountEditorView.swift    # 新建 / 编辑账号
    ├── ConfigImportView.swift     # 配置导入说明
    ├── ShareSheet.swift           # 导出文件的系统分享面板
    ├── Assets.xcassets
    └── Info.plist
```

## 快捷指令配置

1. 打开「快捷指令」，进入「自动化」
2. 新建个人自动化，选择「收到信息」
3. 条件选择「信息内容包含」，填入 `【`
4. 进入下一步后，选择「创建新的快捷指令」
5. 在新快捷指令里添加「账号保存」的「导入商家短信」动作
6. 「发送号码」→ 选择「快捷指令输入」中的「发件人」
7. 「短信内容」→ 选择「快捷指令输入」中的「内容」
8. 「账号名」→ 选择「每次询问」，运行时弹窗输入账号名
9. 关闭「运行前询问」，保存自动化

## 导出格式

| 导出项 | 文件名 | 内容 |
| --- | --- | --- |
| 导出账号 | `账号表格_yyyyMMdd_HHmmss.csv` | UTF-8 BOM 的 CSV，列为 `账号名,注册手机号` |
| 导出短信 | `短信_yyyyMMdd_HHmmss.cab` | 标准 ZIP 容器（存储方式不压缩），内含 `messages.csv`（账号名,注册手机号,发件号码,短信内容,接收时间,验证码）与 `messages.json` |

`.cab` 是标准 ZIP，macOS / iOS 可直接解开，Windows 上也可用 7-Zip 等工具打开。

## 构建

### GitHub Actions（推荐，产出未签名 IPA）

`.github/workflows/build-account-save-ipa.yml` 会在 `main` 分支推送时用 Xcode 编译 arm64 Release，
ad-hoc 签名后打包成 `AccountSave.ipa` 并发布到 Release（tag `account-save`），可直接下载安装。

### 本地 Xcode

用 Xcode 16 打开 `account-save/AccountSave.xcodeproj`，Scheme 选 `AccountSave`，
部署目标 iOS 18.0。真机运行需在 Signing & Capabilities 里选择自己的 Team。

Command Line 打包：

```bash
cd account-save
xcodebuild build \
  -project AccountSave.xcodeproj \
  -scheme AccountSave \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  ARCHS="arm64" ONLY_ACTIVE_ARCH=NO

mkdir -p Payload && cp -R build/Build/Products/Release-iphoneos/AccountSave.app Payload/
zip -r AccountSave.ipa Payload/
```

## 安装

用 Sideloadly / AltStore 等工具配合 Apple ID 重签名后安装到 iOS 18 设备。
