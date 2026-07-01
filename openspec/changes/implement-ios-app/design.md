## Context

AtHome iOS 客户端是产品核心入口：用户扫码配对后，手动触发将相册照片增量备份到家庭服务端。服务端已实现（`implement-server`），API 契约见 `docs/api-server.md`。`ios/` 目录为空，需从零搭建 SwiftUI 工程。

## Goals / Non-Goals

**Goals:**
- Phase 1 MVP：配对 + 手动同步 + 三屏 UI
- SQLite 同步状态（用户照片量大）
- PhotoKit 原图导出，仅本机可用资源
- 前台顺序上传，对接服务端 ping / handshake / upload
- 与本地 Python 接收端联调通过

**Non-Goals:**
- 打开 App 自动同步、在家 ping 检测自动触发（Phase 2）
- 充电 / 每日一次限制、BGAppRefreshTask 后台上传
- 照片浏览、编辑、分享
- 共享相册、SMB/WebDAV 直连
- iCloud 照片拉取（`isNetworkAccessAllowed = false`）

## Decisions

### 1. 工程结构：SwiftUI + MVVM-ish

```
ios/AtHome/
├── AtHomeApp.swift
├── Models/
│   ├── PairingCredentials.swift
│   ├── SyncStats.swift
│   └── UploadTask.swift
├── Services/
│   ├── KeychainService.swift
│   ├── NetworkClient.swift
│   ├── SyncStore.swift          # SQLite
│   ├── PhotoLibraryService.swift
│   └── SyncEngine.swift
├── Views/
│   ├── UnpairedView.swift
│   ├── HomeView.swift
│   ├── SettingsView.swift
│   └── Components/
└── Resources/
    └── Info.plist
```

无第三方 UI 框架；网络用 `URLSession` + `async/await`。

### 2. SQLite：GRDB 或原生 SQLite3

**选择：** GRDB（Swift Package）— API 简洁，迁移方便。

**表结构：**
```sql
CREATE TABLE synced_photos (
    local_identifier TEXT PRIMARY KEY,
    modification_date TEXT NOT NULL,
    synced_at TEXT NOT NULL
);
CREATE INDEX idx_synced_mod ON synced_photos(modification_date);
```

### 3. Keychain 存储

| 键 | 内容 |
|----|------|
| serverId | 对暗号用 |
| userId | 握手凭证 |
| addr | `192.168.x.x:6060` |
| sessionToken | 可选缓存 |
| expiresAt | token 过期时间 |

配对信息与 token 同一 Keychain service，`kSecAttrAccessibleAfterFirstUnlock`。

### 4. modificationDate 序列化

**选择：** 统一 formatter，秒级精度，固定时区 offset：

```swift
// PHAsset.modificationDate → "2025-07-01T10:00:00+08:00"
ISO8601DateFormatter with .withInternetDateTime, .withColonSeparatorInTimeZone
// 截断亚秒
```

避免全量重传时因格式差异导致服务端误判为新 version。

### 5. PhotoKit 导出策略

```swift
PHAssetResourceManager.default().writeData(
    for: resource,
    toFile: tempURL,
    options: PHAssetResourceRequestOptions() // isNetworkAccessAllowed = false
)
```

- 枚举：`PHAsset.fetchAssets(in: userLibrary, options:)` 
- Live Photo：`.photo` + `.pairedVideo` 两个 resource
- 本机不可用：检查 `PHAssetResource.isLocallyAvailable`（iOS 16+）或 write 失败时 skip

### 6. 同步引擎流程

```
SyncEngine.sync()
  1. NetworkClient.ping() 
  2. NetworkClient.handshake() → verify serverId
  3. PhotoLibraryService.fetchAllAssets()
  4. SyncStore.pendingAssets(assets) → [UploadTask]
  5. For each task (sorted by creationDate):
       a. Export to temp file
       b. NetworkClient.upload(...)
       c. On all parts success → SyncStore.markSynced()
  6. Publish SyncStats + completion
```

`UploadTask` 对 Live Photo 含 1–2 个 `UploadPart`（image/video）。

### 7. 网络层

- Base URL: `http://{addr}`（addr 来自 QR，无 scheme）
- multipart 用 `URLSession.upload(for:from:)` 或手动构建 `multipart/form-data`
- 401 `TOKEN_EXPIRED` → 清 token → handshake → 重试一次
- `serverId` 不匹配 → 抛 `ServerIdentityMismatch`，中止同步

### 8. UI 导航

```
@State pairingComplete → if paired { HomeView } else { UnpairedView }
HomeView → NavigationLink → SettingsView
```

`SyncEngine` 作为 `@Observable` 或 `ObservableObject` 注入，主页订阅 `syncProgress` / `syncStats`。

### 9. Info.plist 权限

| Key | 文案要点 |
|-----|----------|
| NSPhotoLibraryUsageDescription | 读取照片用于备份到家里电脑 |
| NSCameraUsageDescription | 扫描配对二维码 |
| NSLocalNetworkUsageDescription | 连接家里照片接收服务 |
| NSBonjourServices | `_http._tcp`（如需要） |

iOS 14+ 本地网络权限对 LAN HTTP 至关重要。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 大量照片首次同步耗时长 | UI 显示进度；Phase 2 再加自动触发 |
| iCloud 未下载照片被跳过 | 统计 skipped 数，设置页说明 |
| modificationDate 格式不一致 | 统一 DateFormatter，联调时对比服务端 |
| HTTP 明文 | MVP 接受；Phase 2 HTTPS |
| 有限相册访问 | 只同步用户授权的子集，符合预期 |
| Live Photo 一半失败 | 不更新 sync record，下次重试补全 |

## Migration Plan

1. 创建 Xcode 工程到 `ios/AtHome/`
2. 实现 Services 层，curl/模拟器联调前用真机 + 局域网服务端测试
3. 更新 `README.md` iOS 构建说明
4. 无数据迁移（绿field）

## Open Questions

- 最低 iOS 版本：建议 **iOS 17+**（SwiftUI 成熟、`isLocallyAvailable` 稳定）；若需 iOS 16 需 fallback 本机检测逻辑
- Xcode 工程是否用 SPM 管理 GRDB：是
