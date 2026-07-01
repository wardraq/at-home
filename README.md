# AtHome

回家的照片，自动存档。

AtHome 是一个极简的 iOS App，连上家里的 WiFi 后自动把照片增量同步到本地硬盘（Mac / PC / NAS）。

## 特性

- **极简** — 只做一件事：在家时自动备份照片到本地
- **增量同步** — 只上传新增和修改的照片，不重复
- **安全配对** — 扫码配对 + serverId 对暗号 + sessionToken，防止误连
- **单向归档** — 手机 → 本地，不反向同步，本地备份防误删
- **免费开源** — MIT License

## 不做的事

- ❌ 照片浏览（Apple 相册已经做得很好）
- ❌ 照片编辑
- ❌ 云端存储
- ❌ 分享功能

## 快速开始

### 接收端（本地电脑）

```bash
pip install -r server/requirements.txt
python server/receive.py
```

- **手机 API**：`http://<局域网IP>:6060`
- **Admin 控制台**：`http://127.0.0.1:6061`（创建用户、显示 QR 码）

详细 API 见 [docs/api-server.md](docs/api-server.md)。

### iOS App

**要求：** Xcode 15+、iOS 17+、真机（需访问局域网）

1. 打开工程：

```bash
open ios/AtHome.xcodeproj
```

2. 在 Xcode 中选择你的 Team，用真机运行
3. 在 Mac 上打开 Admin（`http://127.0.0.1:6061`），创建用户并显示 QR 码
4. iPhone 上：扫描 QR → **测试连接** → 主页点 **立即同步**

**联调检查清单：**

- [ ] 扫码配对 + 测试连接成功
- [ ] 静图上传后，在服务端存储目录可见
- [ ] Live Photo 生成 `_image` + `_video` 两个文件
- [ ] 设置里清除同步记录后重传，服务端不产生重复 version

**权限说明：** App 需要相册（只读）、相机（扫码）、本地网络（连接家里服务器）。

## 项目结构

```
at-home/
├── docs/              # 设计文档与 API 文档
├── ios/AtHome/        # iOS App（Swift + SwiftUI）
├── server/            # Python 接收端
├── mac/               # Mac Companion App（规划中）
└── LICENSE
```

## 分阶段计划

| Phase | 内容 | 状态 |
|-------|------|------|
| 1 | MVP：手动触发 + Python 接收脚本 + iOS 客户端 | 进行中 |
| 2 | 自动触发：App 打开自动检测 + 同步状态界面 | 待开始 |
| 3 | Mac Companion App：菜单栏 App 替换 Python 脚本 | 待开始 |
| 4 | Polish：后台优化、错误重试、充电时同步 | 待开始 |
| 5 | 多路径冗余备份：多块硬盘镜像 | 待开始 |

## License

MIT License - 见 [LICENSE](LICENSE)
