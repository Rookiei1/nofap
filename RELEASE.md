# NoFap 发布

公开源码仓库：`https://github.com/Rookiei1/nofap`，默认分支 `main`。

这是独立的 iPhone App，不使用 RebootWatch 的工程、Bundle ID、scheme 或 Watch 结构。

| 项目 | 值 |
| --- | --- |
| 名称 | NoFap。若 App Store 名称被占用，记录用「掌控此刻」，首页标题仍是 NOFAP |
| 平台 | iOS |
| 语言 | 简体中文（zh-Hans） |
| Bundle ID | `com.rookiei1.nofap` |
| SKU | `nofap-iphone-001` |
| Scheme | NoFap |
| 营销版本 | 1.0.0 |
| 签名目标 | 只有 iPhone 应用 NoFap。测试包不签名上传 |
| 能力 | 无。可选的本地通知不是能力项，也不是每日打卡 |
| 加密 | 不使用自有加密。`ITSAppUsesNonExemptEncryption` 为 NO |
| 最低系统 | iOS 17.0 |
| 编译 | GitHub `macos-26` 上的 Xcode 26.6，iOS 26 SDK |

## 下次发布

Actions → TestFlight → 分支 `main` → Run workflow。

- `diagnose`：只读检查协议、App ID、App Store Connect 记录和已有证书。不创建、不上传。
- `bootstrap`：在缺记录时创建这个 App 的 App ID 和描述文件，复用已有分发证书。不上传，不新建证书。
- `release`：测试、签名、导出 IPA、核对包，然后上传 TestFlight。

源码测试也可以单独走 Actions → Test。绿色测试只说明源码能编过，不等于已经签名或已经上架。

## 签名

正常发布使用 readonly match，不新建、不撤销证书。

私有签名仓库：`https://github.com/Rookiei1/nofap-signing`（private）。分支 `signing-assets-v2` 只放已加密的分发证书文件，从既有签名库原样复制密文。公开仓库用只读 deploy key 读取。

公开仓库 Secrets（只写名称）：

| Secret | 用途 |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | API Issuer ID |
| `ASC_PRIVATE_KEY` | API 密钥全文 |
| `MATCH_PASSWORD_NEXT` | 解密签名库。工作流把它映射为 fastlane 的 `MATCH_PASSWORD` |
| `SIGNING_CERTIFICATE_ID` | 要复用的现有分发证书 ID |
| `SIGNING_STORE_URL` | 私有签名仓库的 SSH 地址 |
| `SIGNING_DEPLOY_KEY` | 该私有仓库的只读 deploy key |

不要把这些值写进仓库、日志或聊天。

## 当前状态

源码测试、签名、上传、Apple 处理和 TestFlight 安装要分开看。以仓库里最新的 Actions 记录为准。正式 App Store 上架不在这次范围内。
