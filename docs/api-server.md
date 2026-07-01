# AtHome 服务端 API 文档

> 版本：1.0（草案）  
> 关联文档：[设计文档](./设计文档.md)

本文档定义 AtHome 本地接收端（服务端）的 HTTP API、数据模型与存储规则，供 iOS App、Python 接收脚本及 Mac Companion App 实现时对齐。

---

## 一、概述

AtHome 服务端是运行在家庭局域网内的轻量 HTTP 接收程序，职责：

- **门卫**：用户配对、握手认证、sessionToken 校验
- **仓库**：接收照片文件，按用户与日期落盘
- **登记**：在本地数据库记录上传元数据与版本信息

服务端**不维护**「手机端已同步集合」——增量同步逻辑由 iOS App 负责。

### 双端口架构

| 端口 | 绑定地址 | 用途 | 访问方 |
|------|----------|------|--------|
| **6060** | `0.0.0.0` | 手机端 API（ping / handshake / upload） | 局域网内 iOS App |
| **6061** | `127.0.0.1` | 管理端 Web UI + Admin API | 仅本机浏览器 |

```
                    ┌─────────────────────────────────────┐
  iOS App ──LAN──▶  │  :6060  手机端 API                   │
                    │    GET  /ping                        │
                    │    POST /handshake                   │
                    │    POST /upload                      │
                    └─────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
  本机浏览器 ─────▶  │  :6061  Admin（127.0.0.1 only）      │
                    │    Web UI + /admin/*                 │
                    └─────────────────────────────────────┘
```

配对二维码中的 `addr` 字段格式：`{局域网IP}:6060`（不含协议前缀）。

---

## 二、公共约定

### 2.1 协议与格式

- 传输协议：HTTP（MVP 阶段明文，HTTPS 为 Phase 2）
- 请求 / 响应编码：UTF-8
- JSON 请求：`Content-Type: application/json`
- 文件上传：`Content-Type: multipart/form-data`
- 时间格式：ISO 8601，带时区，如 `2025-07-01T15:00:00+08:00` 或 UTC `2025-07-01T07:00:00Z`

### 2.2 ID 格式

| 类型 | 前缀 | 示例 | 说明 |
|------|------|------|------|
| serverId | `srv-` | `srv-F2A8B1C3D4E5` | 服务端唯一标识，首次启动生成 |
| userId | `usr-` | `usr-a3f28b1ce5914d7a` | 用户凭证，128-bit 随机串 |
| sessionToken | `st-` | `st-abc123...` | 握手后签发的会话令牌 |

### 2.3 统一响应结构

**成功：**

```json
{
  "status": "ok",
  ...
}
```

**失败：**

```json
{
  "status": "error",
  "code": "ERROR_CODE",
  "message": "人类可读的错误描述"
}
```

### 2.4 HTTP 状态码

| 状态码 | 含义 |
|--------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未认证或 token 无效 |
| 403 | 用户已吊销 |
| 409 | 冲突（如 modificationDate 回拨） |
| 413 | 文件过大 |
| 500 | 服务端内部错误 |

### 2.5 错误码一览

| code | 说明 |
|------|------|
| `USER_NOT_FOUND` | userId 不存在 |
| `USER_REVOKED` | 用户已被吊销 |
| `INVALID_TOKEN` | sessionToken 无效 |
| `TOKEN_EXPIRED` | sessionToken 已过期 |
| `MODIFICATION_REGRESSION` | modificationDate 早于已记录值 |
| `INVALID_PART` | part 字段非法 |
| `MISSING_FIELD` | 缺少必填字段 |
| `STORAGE_ERROR` | 写入磁盘失败 |

---

## 三、认证模型

### 3.1 配对（QR 码）

管理员在 Admin Web UI 创建用户后，生成二维码。Payload 为 JSON：

```json
{
  "serverId": "srv-F2A8B1C3D4E5",
  "userId": "usr-a3f28b1ce5914d7a",
  "addr": "192.168.1.100:6060"
}
```

手机扫码后将 `serverId`、`userId`、`addr` 存入 Keychain，无需手动输入。

### 3.2 握手流程

```
手机                          服务端
 │                              │
 │  POST /handshake             │
 │  { userId, deviceName }      │
 │ ────────────────────────────▶│  验证 userId 存在且 active
 │                              │  签发 sessionToken
 │  { serverId, sessionToken,   │
 │    userName, expiresAt }     │
 │ ◀────────────────────────────│
 │                              │
 │  验证 serverId 与 QR 一致     │
 │  一致 → 保存 token，可上传    │
 │  不一致 → 断开，不传照片       │
```

- 手机**不发送** serverId；serverId 由服务端在响应中亮明，供手机「对暗号」
- sessionToken TTL：**7 天**
- 连接中断后不复用旧 token，需重新握手
- 用户被吊销后，该用户所有 sessionToken 立即失效
- 同一 userId 可同时持有多个有效 sessionToken（多设备）

### 3.3 上传认证

```
Authorization: Bearer <sessionToken>
```

---

## 四、手机端 API（:6060）

### 4.1 `GET /ping`

检测服务端是否可达（「在家」检测），无需认证。

**Response 200**

```json
{
  "status": "ok",
  "serverId": "srv-F2A8B1C3D4E5",
  "version": "1.0.0"
}
```

---

### 4.2 `POST /handshake`

发起握手，获取 sessionToken。

**Request**

```json
{
  "userId": "usr-a3f28b1ce5914d7a",
  "deviceName": "iPhone 15 Pro"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| userId | string | ✓ | 扫码获得的用户凭证 |
| deviceName | string | ✓ | 设备名称，用于管理端展示 |

**Response 200**

```json
{
  "status": "ok",
  "serverId": "srv-F2A8B1C3D4E5",
  "sessionToken": "st-abc123def456",
  "userName": "wardraq",
  "expiresAt": "2025-07-08T15:00:00+08:00"
}
```

**Response 401 / 403**

```json
{
  "status": "error",
  "code": "USER_NOT_FOUND",
  "message": "用户未授权"
}
```

```json
{
  "status": "error",
  "code": "USER_REVOKED",
  "message": "用户已被吊销"
}
```

---

### 4.3 `POST /upload`

上传单张照片或 Live Photo 的一个资源（图片或视频）。MVP 仅支持单张；未来可增加 `POST /upload/batch` 批量接口，字段保持一致。

**Headers**

```
Authorization: Bearer <sessionToken>
Content-Type: multipart/form-data
```

**Form 字段**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| file | binary | ✓ | 照片或视频文件 |
| localIdentifier | string | ✓ | PhotoKit 资产 ID（见 §6.1） |
| modificationDate | string | ✓ | ISO 8601，**版本判定依据** |
| creationDate | string | ✓ | ISO 8601，拍摄时间，决定存储目录 YYYY/MM |
| part | string | ✓ | `image` 或 `video` |
| originalFilename | string | | 原始文件名，如 `IMG_0042.HEIC`，仅展示/日志 |
| mimeType | string | | 如 `image/heic`、`video/quicktime` |

**注意：手机端不上传 `version`**。版本号由服务端根据 `modificationDate` 变化自动分配（见 §5.3）。

**part 取值规则**

| 照片类型 | 上传次数 | part |
|----------|----------|------|
| JPEG / PNG / HEIC 静图 | 1 | `image` |
| Live Photo | 2 | `image` + `video` |

Live Photo 的两次请求共用相同的 `localIdentifier` 和 `modificationDate`，服务端分配相同 version，用 `part` 区分。

**Response 200**

```json
{
  "status": "ok",
  "localIdentifier": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890/L0/001",
  "version": 3,
  "part": "image",
  "path": "wardraq/2025/07/A1B2C3D4-E5F6-7890-ABCD-EF1234567890_L0_001_v3_image.HEIC",
  "uploadedAt": "2025-07-01T10:00:00+08:00"
}
```

**Response 401**

```json
{
  "status": "error",
  "code": "TOKEN_EXPIRED",
  "message": "会话已过期，请重新握手"
}
```

**Response 409**

```json
{
  "status": "error",
  "code": "MODIFICATION_REGRESSION",
  "message": "modificationDate 早于已记录值"
}
```

---

## 五、版本与幂等规则

### 5.1 职责分工

| 端 | 职责 |
|----|------|
| **iOS** | 判断是否需要上传：`localIdentifier` 不在已同步记录，或 `modificationDate` 与本地记录不一致 |
| **服务端** | 分配 version、落盘、写入 metadata 数据库 |

iOS 本地同步表（无需 version 列）：

```
| localIdentifier | modificationDate | syncedAt |
```

### 5.2 版本分配逻辑

服务端以 `(userId, localIdentifier, modificationDate)` 标识一次逻辑上传：

```
收到 POST /upload
    │
    ├─ 无此 localIdentifier
    │     → version = 1
    │
    ├─ 有，且 modificationDate == current_modification_date
    │     → 沿用 current_version（幂等）
    │     → 同 part：覆盖同路径文件
    │     → 不同 part：补全 Live Photo 的另一资源
    │
    └─ 有，且 modificationDate > current_modification_date
          → version = current_version + 1
          → 旧 version 文件保留在磁盘
          → 更新 assets.current_version 与 current_modification_date
```

**modificationDate 早于已记录值** → 返回 `409 MODIFICATION_REGRESSION`，不写入。

### 5.3 Live Photo 示例

```
# 首次上传 Live Photo（modificationDate = T1）
POST /upload  localIdentifier=X, mod=T1, part=image  →  version=1
POST /upload  localIdentifier=X, mod=T1, part=video   →  version=1（mod 未变，不递增）

# 编辑后重新上传（modificationDate = T2）
POST /upload  localIdentifier=X, mod=T2, part=image  →  version=2
POST /upload  localIdentifier=X, mod=T2, part=video   →  version=2

# v1 文件仍保留在磁盘
```

### 5.4 清除同步记录后全量重传

iOS 清空本地同步记录后重新上传：`modificationDate` 未变 → 服务端幂等处理，**不会**产生新版本号。

---

## 六、存储规则

### 6.1 localIdentifier 说明

`localIdentifier` 是 Apple PhotoKit 为相册资源分配的系统 ID，**不是文件名**。

典型格式：

```
A1B2C3D4-E5F6-7890-ABCD-EF1234567890/L0/001
└────────── UUID ──────────────────────┘ └┬┘ └┬┘
                                         L0  001
                                      库作用域 库内序号
```

特点：

- 含 `/` 字符，不可直接作为文件名
- 长度约 45–50 字符
- 同一张照片编辑后通常不变，`modificationDate` 会变
- 复制照片会产生新的 `localIdentifier`

### 6.2 文件名消毒规则

将 `localIdentifier` 原串消毒后用于文件名：

```
原始:  A1B2C3D4-E5F6-7890-ABCD-EF1234567890/L0/001
消毒:  A1B2C3D4-E5F6-7890-ABCD-EF1234567890_L0_001

规则:
  1. / → _
  2. 移除或替换其余非法文件名字符（如 \ : * ? " < > |）
```

完整文件名格式：

```
{sanitized_localIdentifier}_v{version}_{part}.{ext}

示例:
  A1B2C3D4-E5F6-7890-ABCD-EF1234567890_L0_001_v3_image.HEIC
  A1B2C3D4-E5F6-7890-ABCD-EF1234567890_L0_001_v3_video.mov
```

扩展名从上传文件的 `originalFilename` 或 `mimeType` 推断。

### 6.3 目录结构

按用户 name（不可改）隔离，按拍摄日期分目录：

```
{storagePath}/
├── wardraq/                          ← 用户 name
│   ├── 2024/
│   │   ├── 01/
│   │   │   ├── ..._v1_image.HEIC
│   │   │   └── ..._v1_video.mov
│   │   └── 02/
│   └── 2025/
│       └── 07/
│           ├── ..._v1_image.HEIC
│           ├── ..._v2_image.HEIC     ← 编辑后新版本，v1 仍保留
│           └── ..._v2_video.mov
└── 妈妈/
    └── 2025/
        └── ...
```

`YYYY/MM` 由请求中的 `creationDate` 决定。

---

## 七、管理端 API（:6061，仅 localhost）

Admin 端口仅绑定 `127.0.0.1`，不暴露给局域网。提供极简 Web UI 及 JSON API。

### 7.1 `GET /`

Admin Web UI 首页。功能（MVP）：

- 显示 serverId、服务地址（`:6060`）、存储路径
- 用户列表（创建 / 吊销 / 查看 QR 码）
- 最近上传记录
- 磁盘空间概览

### 7.2 `GET /admin/status`

**Response 200**

```json
{
  "status": "ok",
  "serverId": "srv-F2A8B1C3D4E5",
  "apiAddr": "192.168.1.100:6060",
  "storagePath": "/Volumes/Backup/Photos",
  "diskFreeBytes": 1099511627776,
  "uptime": 86400
}
```

### 7.3 `GET /admin/users`

**Response 200**

```json
{
  "status": "ok",
  "users": [
    {
      "userId": "usr-a3f28b1ce5914d7a",
      "name": "wardraq",
      "status": "active",
      "createdAt": "2025-07-01T15:00:00+08:00",
      "assetCount": 5200,
      "lastUploadAt": "2025-07-01T10:00:00+08:00"
    }
  ]
}
```

### 7.4 `POST /admin/users`

创建新用户。

**Request**

```json
{
  "name": "wardraq"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | string | ✓ | 用户标签，创建后不可修改，作为存储目录名 |

**Response 200**

```json
{
  "status": "ok",
  "userId": "usr-a3f28b1ce5914d7a",
  "name": "wardraq",
  "qrPayload": {
    "serverId": "srv-F2A8B1C3D4E5",
    "userId": "usr-a3f28b1ce5914d7a",
    "addr": "192.168.1.100:6060"
  }
}
```

### 7.5 `DELETE /admin/users/{userId}`

吊销用户。该用户所有 sessionToken 立即失效，不再接受上传。

**Response 200**

```json
{
  "status": "ok",
  "userId": "usr-a3f28b1ce5914d7a",
  "status": "revoked"
}
```

已落盘文件不删除。

### 7.6 `GET /admin/users/{userId}/qrcode`

获取指定用户的配对二维码。

**Response 200**（`Accept: application/json`）

```json
{
  "status": "ok",
  "qrPayload": {
    "serverId": "srv-F2A8B1C3D4E5",
    "userId": "usr-a3f28b1ce5914d7a",
    "addr": "192.168.1.100:6060"
  }
}
```

**Response 200**（`Accept: image/png`）

返回 QR 码 PNG 图片。

### 7.7 `GET /admin/uploads/recent`

最近上传记录，数据来自 metadata 数据库。

**Query 参数**

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| limit | int | 50 | 返回条数，最大 200 |

**Response 200**

```json
{
  "status": "ok",
  "uploads": [
    {
      "userId": "usr-a3f28b1ce5914d7a",
      "userName": "wardraq",
      "localIdentifier": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890/L0/001",
      "version": 3,
      "part": "image",
      "path": "wardraq/2025/07/..._v3_image.HEIC",
      "fileSize": 2457600,
      "uploadedAt": "2025-07-01T10:00:00+08:00"
    }
  ]
}
```

### 7.8 `PUT /admin/settings`

更新服务端配置。

**Request**

```json
{
  "storagePath": "/Volumes/Backup/Photos"
}
```

**Response 200**

```json
{
  "status": "ok",
  "storagePath": "/Volumes/Backup/Photos"
}
```

---

## 八、持久化数据模型

服务端数据分三层，互相隔离：

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ config.json  │  │ sessions     │  │ metadata.db  │
│ 基础配置      │  │ 内存 + 落盘   │  │ SQLite       │
└──────────────┘  └──────────────┘  └──────────────┘
```

### 8.1 config.json

仅存基础配置与用户列表，**不含** sessionToken 和上传记录。

```json
{
  "serverId": "srv-F2A8B1C3D4E5",
  "storagePath": "/Volumes/Backup/Photos",
  "apiPort": 6060,
  "adminPort": 6061,
  "users": [
    {
      "id": "usr-a3f28b1ce5914d7a",
      "name": "wardraq",
      "status": "active",
      "createdAt": "2025-07-01T15:00:00+08:00"
    }
  ]
}
```

首次启动时自动生成 `serverId`。

### 8.2 sessions（内存 + 落盘）

sessionToken 与 config 隔离存储。启动时从落盘文件加载到内存，运行时热查。

| 字段 | 说明 |
|------|------|
| token | sessionToken 值 |
| userId | 关联用户 |
| deviceName | 握手时的设备名 |
| createdAt | 签发时间 |
| expiresAt | 过期时间（创建后 7 天） |

规则：

- 过期 token 定期清理
- 用户吊销 → 删除该用户所有 session
- 同一 userId 可有多条有效 session（多设备）

### 8.3 metadata.db（SQLite）

#### 表 `assets` — 逻辑资产

| 字段 | 类型 | 说明 |
|------|------|------|
| user_id | TEXT | 用户 ID |
| local_identifier | TEXT | PhotoKit 资产 ID |
| current_version | INTEGER | 当前最新版本号 |
| current_modification_date | TEXT | 当前版本的 modificationDate（ISO 8601） |
| creation_date | TEXT | 拍摄时间 |
| original_filename | TEXT | 可选，最近一次的原始文件名 |
| updated_at | TEXT | 最后更新时间 |

唯一约束：`(user_id, local_identifier)`

#### 表 `uploads` — 每次实际上传

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 自增主键 |
| user_id | TEXT | 用户 ID |
| local_identifier | TEXT | PhotoKit 资产 ID |
| version | INTEGER | 版本号 |
| part | TEXT | `image` 或 `video` |
| modification_date | TEXT | 该版本的 modificationDate |
| file_path | TEXT | 磁盘相对路径 |
| file_size | INTEGER | 字节数 |
| content_hash | TEXT | 可选，后续完整性校验 |
| uploaded_at | TEXT | 上传时间 |

唯一约束：`(user_id, local_identifier, version, part)`

---

## 九、安全边界

| 威胁 | MVP 防护 | 说明 |
|------|----------|------|
| 连错邻居服务器 | 握手时 serverId 对暗号 | 有效 |
| 扫错 QR 码 | serverId 不匹配则断开 | 有效 |
| 未授权上传 | userId + sessionToken | 有效 |
| Admin 被远程访问 | 6061 仅 127.0.0.1 | 有效 |
| 主动中间人（MITM） | 无 | HTTP 明文下的上限；Phase 2 考虑 HTTPS + 证书 pin |

---

## 十、未来扩展

以下不在 MVP 范围内，接口设计预留扩展空间：

| 功能 | 说明 |
|------|------|
| `POST /upload/batch` | 批量上传，字段与单张一致 |
| HTTPS | TLS 加密 + 证书 pin |
| content_hash 校验 | 上传时计算哈希，定期完整性检查 |
| 内容去重 | 按哈希合并重复照片 |

---

## 附录 A：完整交互时序

```
管理员（本机）                服务端                    iOS App
     │                          │                          │
     │  创建用户 wardraq         │                          │
     │ ────────────────────────▶│                          │
     │  显示 QR 码               │                          │
     │ ◀────────────────────────│                          │
     │                          │                          │
     │                          │     扫码，存 Keychain      │
     │                          │ ◀────────────────────────│
     │                          │                          │
     │                          │     GET /ping            │
     │                          │ ◀────────────────────────│
     │                          │     POST /handshake      │
     │                          │ ◀────────────────────────│
     │                          │     验证 serverId         │
     │                          │                          │
     │                          │     POST /upload (×N)    │
     │                          │ ◀────────────────────────│
     │                          │     落盘 + 写 metadata    │
     │                          │                          │
     │  查看最近上传              │                          │
     │ ────────────────────────▶│                          │
     │ ◀────────────────────────│                          │
```

## 附录 B：文档关系

[设计文档](./设计文档.md) 为产品级设计，本文档为服务端实现级 API 契约。两份文档已对齐，服务端相关细节以本文档为准。
