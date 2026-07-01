# AtHome

回家的照片，自动存档。

AtHome 是一个极简的 iOS App，连上家里的 WiFi 后自动把照片增量同步到本地硬盘（Mac / PC / NAS）。

## 特性

- **极简** — 只做一件事：在家时自动备份照片到本地
- **增量同步** — 只上传新增和修改的照片，不重复
- **安全配对** — UUID + 验证码握手验证，防止误连
- **单向归档** — 手机 → 本地，不反向同步，本地备份防误删
- **免费开源** — MIT License

## 不做的事

- ❌ 照片浏览（Apple 相册已经做得很好）
- ❌ 照片编辑
- ❌ 云端存储
- ❌ 分享功能

## 快速开始

> MVP 阶段，开发进行中

### 接收端（本地电脑）

```bash
# Python 接收脚本（Phase 1 MVP）
pip install flask
python receive.py
```

### iOS App

在 App Store 下载 / TestFlight 安装后：

1. 扫描本地接收端显示的二维码（包含 UUID + 验证码）
2. 连上家里 WiFi，打开 App 即自动同步

## 项目结构

```
at-home/
├── docs/              # 设计文档
├── ios/               # iOS App（Swift + SwiftUI）
├── mac/               # Mac Companion App（菜单栏 App）
├── server/            # 接收端脚本（Python）
└── LICENSE
└── README.md
```

## 分阶段计划

| Phase | 内容 | 状态 |
|-------|------|------|
| 1 | MVP：手动触发 + Python 接收脚本 + 握手验证 | 开发中 |
| 2 | 自动触发：App 打开自动检测 + 同步状态界面 | 待开始 |
| 3 | Mac Companion App：菜单栏 App 替换 Python 脚本 | 待开始 |
| 4 | Polish：后台优化、错误重试、充电时同步 | 待开始 |
| 5 | 多路径冗余备份：多块硬盘镜像 | 待开始 |

## License

MIT License - 见 [LICENSE](LICENSE)
