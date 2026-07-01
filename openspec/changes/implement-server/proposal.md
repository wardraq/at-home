## Why

AtHome Phase 1 MVP 需要本地照片接收端，让 iOS App 能通过 HTTP 将照片增量备份到家庭硬盘。当前 `server/receive.py` 为空，缺少可运行的接收服务，阻塞 iOS 端联调与端到端验证。服务端 API 与数据模型已在 `docs/api-server.md` 中定义完毕，现在需要落地实现。

## What Changes

- 实现 Python 接收端（`server/receive.py`），双端口架构：`:6060` 手机 API、`:6061` Admin Web UI
- 实现手机端 API：`GET /ping`、`POST /handshake`、`POST /upload`
- 实现管理端 API 与极简 Web UI：用户创建/吊销、QR 码、最近上传、存储路径配置
- 实现三层持久化：`config.json`（基础配置）、sessions（内存 + 落盘）、`metadata.db`（SQLite）
- 实现照片落盘规则：按用户 name + creationDate 分目录，localIdentifier 消毒命名，服务端维护 version
- 添加 `requirements.txt` 与启动说明

## Capabilities

### New Capabilities

- `server-mobile-api`: 手机端可达性检测、握手认证、单张照片上传（含 version 分配与幂等）
- `server-admin`: 本机 Admin Web UI 与用户/配置管理 API（127.0.0.1:6061）
- `server-persistence`: config、sessions、metadata 数据库与文件存储

### Modified Capabilities

（无既有 spec）

## Impact

- **新增代码**：`server/` 目录下 Python 模块（receive.py 及辅助模块）
- **依赖**：flask、werkzeug、qrcode 等（requirements.txt）
- **数据文件**：运行时生成 config.json、sessions 文件、metadata.db、照片存储目录
- **文档**：实现以 `docs/api-server.md` 为契约，无需修改 API 文档
- **下游**：完成后 iOS App 可开始联调 ping / handshake / upload
