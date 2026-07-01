## Why

AtHome 服务端（`implement-server`）已完成，可接收 ping / handshake / upload。`ios/` 目录仍为空，缺少 iOS 客户端，无法完成「扫码配对 → 增量备份照片到家里硬盘」的核心用户流程。现在需要实现 Phase 1 MVP 客户端，与服务端联调验证端到端链路。

## What Changes

- 新建 Swift + SwiftUI iOS App 工程（`ios/`）
- 实现扫码配对：解析 QR payload，Keychain 存储 `serverId` / `userId` / `addr`
- 实现网络层：`GET /ping`、`POST /handshake`、`POST /upload`（multipart），sessionToken 生命周期管理
- 实现 SQLite 同步状态库：`localIdentifier` + `modificationDate` + `syncedAt`
- 实现 PhotoKit 导出：原图资源、仅本机可用照片、`isNetworkAccessAllowed = false`
- 实现同步引擎：增量集合运算、前台顺序上传队列（含 Live Photo 双 part）
- 实现三屏 UI：未配对 / 主页（状态 + 手动同步）/ 设置（清除记录 + 确认）
- 添加必要权限声明：相册只读、相机扫码、本地网络访问

**Phase 1 不做：** 打开 App 自动同步、在家 ping 自动触发、充电限制、后台 BGTask、照片浏览。

## Capabilities

### New Capabilities

- `ios-pairing`: 扫码配对、Keychain 凭证存储、连接测试（ping + handshake + serverId 验暗号）
- `ios-network`: HTTP 客户端，对接服务端 :6060 API
- `ios-sync-store`: SQLite 已同步记录，增量判断与统计（待同步/已同步/已归档）
- `ios-photo-library`: PhotoKit 枚举与原图导出，仅本机可用资源
- `ios-sync-engine`: 同步状态机、上传队列、Live Photo 处理、错误重试
- `ios-ui`: 三屏 SwiftUI（未配对 / 主页 / 设置）

### Modified Capabilities

（无既有 spec）

## Impact

- **新增代码**：`ios/` 完整 Xcode 工程及 Swift 源码
- **依赖**：系统框架 PhotoKit、Security（Keychain）、SQLite（GRDB 或原生 SQLite3）
- **权限**：Info.plist 需 `NSPhotoLibraryUsageDescription`、`NSCameraUsageDescription`、`NSLocalNetworkUsageDescription`
- **下游**：可与运行中的 Python 接收端（`:6060` / `:6061`）联调
- **文档**：实现以 `docs/api-server.md` 和 `docs/设计文档.md` 为契约
