## 1. 项目脚手架

- [x] 1.1 创建 `server/requirements.txt`（flask、werkzeug、qrcode[pil]）
- [x] 1.2 创建 `server/data/.gitkeep`，在 `.gitignore` 中忽略 `server/data/*`（保留 .gitkeep）
- [x] 1.3 搭建模块目录结构（config、sessions、metadata、storage、version、api/）

## 2. 持久化层

- [x] 2.1 实现 `config.py`：读写 config.json，首次启动生成 serverId，用户 CRUD
- [x] 2.2 实现 `sessions.py`：内存 dict + sessions.json 落盘，签发/验证/吊销/过期清理
- [x] 2.3 实现 `metadata.py`：SQLite 初始化（assets、uploads 表），CRUD 与查询（recent uploads、assetCount）
- [x] 2.4 实现 `storage.py`：localIdentifier 消毒、路径生成、文件写入
- [x] 2.5 实现 `version.py`：version 分配逻辑（新增/递增/幂等/409 回拨检测）

## 3. 手机端 API（:6060）

- [x] 3.1 实现 `GET /ping`：返回 serverId 与 version
- [x] 3.2 实现 `POST /handshake`：userId 验证、签发 sessionToken、错误码 USER_NOT_FOUND / USER_REVOKED
- [x] 3.3 实现 `POST /upload`：multipart 解析、token 验证、version 分配、落盘、写 metadata
- [x] 3.4 实现 upload 错误处理：INVALID_TOKEN、TOKEN_EXPIRED、MODIFICATION_REGRESSION、MISSING_FIELD

## 4. 管理端 API + Web UI（:6061）

- [x] 4.1 实现 `GET /admin/status` 与 `PUT /admin/settings`
- [x] 4.2 实现 `GET/POST /admin/users` 与 `DELETE /admin/users/{userId}`
- [x] 4.3 实现 `GET /admin/users/{userId}/qrcode`（JSON 与 PNG）
- [x] 4.4 实现 `GET /admin/uploads/recent`
- [x] 4.5 实现 Admin Web UI（`templates/index.html`）：用户管理、QR 展示、状态面板

## 5. 服务启动与集成

- [x] 5.1 实现 `receive.py` 入口：双端口启动（6060 + 127.0.0.1:6061），共享 store 实例与线程锁
- [x] 5.2 实现 LAN IP 检测，用于 QR payload 的 `addr` 字段
- [x] 5.3 添加启动参数（--data-dir、--storage-path、--api-port、--admin-port）

## 6. 验证与文档

- [x] 6.1 手动测试：创建用户 → handshake → 上传静图 → 验证落盘路径与 metadata
- [x] 6.2 手动测试：Live Photo 两次上传（image + video）同 version
- [x] 6.3 手动测试：编辑照片（新 modificationDate）→ version 递增，旧文件保留
- [x] 6.4 手动测试：吊销用户 → token 失效；Admin 仅 localhost 可访问
- [x] 6.5 更新 `README.md` 快速开始（端口 6060/6061、安装与启动命令）
