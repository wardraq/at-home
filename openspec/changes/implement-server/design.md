## Context

AtHome 需要 Phase 1 可运行的 Python 接收端。`docs/api-server.md` 已定义完整 API 契约；`server/receive.py` 当前为空。本 change 实现该契约，为 iOS App 联调提供目标服务。

约束：
- MVP 使用 Python + Flask，单进程双端口
- 实现须严格对齐 `docs/api-server.md`
- 不实现 HTTPS、批量上传、内容哈希（留待后续）

## Goals / Non-Goals

**Goals:**
- 可运行的 `server/receive.py` 入口，一键启动双端口服务
- 完整实现手机端 API（ping / handshake / upload）
- 完整实现 Admin Web UI + Admin API（6061 localhost）
- 三层持久化：config.json、sessions 文件、metadata.db
- 照片按用户 + 日期 + 消毒 localIdentifier 落盘，服务端维护 version

**Non-Goals:**
- Mac Companion App（Swift）
- `POST /upload/batch` 批量上传
- HTTPS / 证书 pin
- 内容哈希去重与完整性校验
- 单元测试框架搭建（可在 tasks 中列为可选）

## Decisions

### 1. 框架：Flask + 双进程/双线程

**选择：** 单 Python 进程内启动两个 Flask app（或 werkzeug `make_server`），分别绑定 `0.0.0.0:6060` 和 `127.0.0.1:6061`。

**理由：** MVP 最简，与文档示例 `pip install flask` 一致。

**备选：** 单 Flask app 用 middleware 区分端口——不可行，需两个 listener。

**实现：** 主线程跑 API server，daemon 线程跑 Admin server；共享同一套 store 实例（需线程锁）。

### 2. 模块结构

```
server/
├── receive.py          # 入口：解析参数、启动双服务
├── config.py           # config.json 读写
├── sessions.py         # session 内存 + JSON 落盘
├── metadata.py         # SQLite assets/uploads 表
├── storage.py          # 文件落盘、localIdentifier 消毒、路径生成
├── version.py          # version 分配逻辑
├── api/
│   ├── mobile.py       # /ping, /handshake, /upload 路由
│   └── admin.py        # /admin/* 路由
├── templates/
│   └── index.html      # Admin Web UI
└── static/             # 可选 CSS
```

**理由：** 单文件会超 500 行，按职责拆分便于测试和维护。

### 3. 数据目录

**选择：** 默认数据目录为 `server/data/`（config.json、sessions.json、metadata.db），照片存储路径默认 `server/data/photos/`，可通过 Admin 或启动参数修改。

**理由：** 开发时路径可预测；与代码仓库分离（加入 .gitignore）。

### 4. Session 存储

**选择：** `sessions.json` 数组，启动时加载到内存 dict，握手/吊销时写回。定期清理过期 token。

**理由：** 用户量极小（家庭几台手机），JSON 足够；与 config 隔离满足 spec。

### 5. Version 逻辑

**选择：** 独立 `version.py` 模块，upload 流程：
1. 查 `assets` 表 by `(user_id, local_identifier)`
2. 不存在 → version=1，insert asset
3. 存在且 `modificationDate` 相同 → 沿用 `current_version`
4. 存在且 `modificationDate` 更新 → `current_version + 1`，旧文件保留
5. 存在且 `modificationDate` 更早 → 409

日期比较：解析为 timezone-aware datetime 后比较。

### 6. Admin Web UI

**选择：** Flask `render_template` + 极简 HTML（无前端框架），内联 CSS。页面通过 fetch 调用同源 Admin API，或 server-side 渲染用户列表。

**理由：** MVP 够用，零构建步骤。

### 7. QR 码

**选择：** `qrcode` 库生成 PNG；JSON payload 与 api-server.md 一致。

**LAN IP 检测：** 启动时枚举非 loopback IPv4 地址，取第一个作为 `addr`；获取失败时回退 `127.0.0.1:6060` 并 Admin 页警告。

### 8. 依赖

```
flask>=3.0
werkzeug>=3.0
qrcode[pil]>=7.4
```

SQLite 使用标准库 `sqlite3`，无需额外 ORM。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 双线程共享 store 竞态 | 对 config/sessions/metadata 写操作加 `threading.Lock` |
| LAN IP 检测不准（多网卡） | Admin 页展示检测到的 IP，文档说明可手动确认 |
| 大文件上传内存占用 | 使用 `werkzeug` 流式写入临时文件再 move |
| sessions.json 损坏 | 启动时 try/except，损坏则备份并重建空 sessions |
| SQLite 并发写 | 单家庭低并发可接受；连接 per-request + WAL 模式 |

## Migration Plan

1. 添加 `server/requirements.txt`
2. 实现并本地手动测试：创建用户 → 扫码 payload → curl handshake → curl upload
3. 更新 `README.md` 快速开始（端口 6060/6061）
4. 无生产迁移（绿field 项目）

## Open Questions

- 上传文件大小上限：建议默认 500MB，可通过 config 配置（tasks 中实现）
- `server/data/` 是否加入 `.gitignore`：是
