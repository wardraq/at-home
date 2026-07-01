## 1. 工程脚手架

- [x] 1.1 创建 Xcode SwiftUI 工程 `ios/AtHome/`，最低 iOS 17
- [x] 1.2 添加 SPM 依赖 GRDB，配置 Info.plist 权限（相册、相机、本地网络）
- [x] 1.3 搭建目录结构（Models / Services / Views）

## 2. 基础设施

- [x] 2.1 实现 `KeychainService`：读写 serverId / userId / addr / sessionToken
- [x] 2.2 实现 `ISO8601` 日期格式化工具（秒级精度、固定时区）
- [x] 2.3 实现 `SyncStore`：SQLite 建表、upsert、查询、清空、统计

## 3. 网络层

- [x] 3.1 实现 `NetworkClient.ping()` 与 `handshake()`
- [x] 3.2 实现 `NetworkClient.upload()` multipart 上传
- [x] 3.3 实现 token 过期自动 re-handshake 与 serverId 验暗号错误处理

## 4. PhotoKit

- [x] 4.1 实现相册权限请求（只读）
- [x] 4.2 实现相机胶卷枚举（smart album user library）
- [x] 4.3 实现原图资源导出（`isNetworkAccessAllowed = false`）
- [x] 4.4 实现 Live Photo 双资源导出（image + video）
- [x] 4.5 实现本机不可用照片跳过逻辑

## 5. 同步引擎

- [x] 5.1 实现增量判断：pending 集合运算 + modificationDate 比较
- [x] 5.2 实现 `SyncEngine`：ping → handshake → 队列 → 顺序上传
- [x] 5.3 实现进度与统计发布（待同步/已同步/已归档/当前进度）
- [x] 5.4 实现单张失败继续、结束后汇总报告

## 6. UI

- [x] 6.1 实现 `UnpairedView`：扫码 + 测试连接
- [x] 6.2 实现 `HomeView`：统计面板 + 立即同步 + 进度
- [x] 6.3 实现 `SettingsView`：配对信息 + 清除记录（含确认文案）
- [x] 6.4 实现 App 根导航（配对状态切换）

## 7. 联调与文档

- [ ] 7.1 真机联调：扫码配对 → 手动同步静图 → 验证服务端落盘
- [ ] 7.2 真机联调：Live Photo 双 part 上传
- [ ] 7.3 真机联调：清除同步记录后全量重传（验证服务端幂等）
- [x] 7.4 更新 `README.md` iOS 构建与运行说明

> 注：1.2 实现采用原生 SQLite3（非 GRDB SPM），避免包解析依赖；模拟器编译已通过，7.1–7.3 需真机与局域网服务端联调。
