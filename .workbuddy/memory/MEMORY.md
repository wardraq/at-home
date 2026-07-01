# AtHome 项目记忆

## 项目概述
- 产品名：AtHome — 「回家的照片，自动存档」
- 极简 iOS App，连上家庭 WiFi 后自动增量同步照片到本地硬盘
- 不是照片浏览器、不是云备份、不是编辑工具

## 核心架构决策
- **多用户模型**：服务端维护用户列表，每台手机一个用户（独立 userId）
- **userId 合一**：userId 是长随机串（UUID级），同时充当身份标识和认证凭证，无需验证码
- **客户端验证服务端**：安全方向是手机确认服务器身份（防伪装服务器偷照片），握手时手机验证 serverId 对暗号
- **QR 码配对**：包含 serverId + userId + serverAddr，手机扫码零手动输入
- **按用户隔离存储**：目录顶层按用户 name（不可改）隔离
- **sessionToken TTL 7天**：超期或断连需重新握手验暗号
- **HTTP MVP**：握手验一次 serverId 信任后续 token；HTTP 明文下每次验也无法防 MITM，真正防护需 HTTPS（Phase 2）

## 服务端 API
- GET /ping — 可达性检测
- POST /handshake — userId → serverId + sessionToken + userName
- POST /upload — Bearer token + 照片
- POST /admin/user — 创建用户
- DELETE /admin/user/{userId} — 吊销用户
- GET /admin/qrcode/{userId} — 配对 QR 码
- GET /admin/users — 用户列表

## 存储结构
Photos Backup/{userName}/YYYY/MM/ — 按用户隔离，按拍摄日期分目录

## 技术栈
- iOS: Swift + SwiftUI + PhotoKit
- Mac Companion: Swift + SwiftUI + GCDWebServer
- MVP 接收端: Python Flask
