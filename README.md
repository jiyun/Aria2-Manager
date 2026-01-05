# Aria2-Manager
> 🚀 一站式 Aria2 下载管理解决方案 | 开箱即用 • 极简便携
## ✨ 项目简介
Aria2-Manager 是一款专为 Windows 环境打造的轻量级下载管理工具。本项目整合了多个优秀开源项目，提供一个**图形化、易上手**的 Aria2 使用体验。
**主要特性：**
- 📦 **开箱即用** - 无需复杂配置，一键启动即可使用
- 🎯 **双界面管理** - 同时查看命令行输出与 AriaNg 图形界面
- 🔄 **智能进程管理** - 自动捕获 Aria2c 进程，后台持久运行
- 💚 **绿色便携** - 单文件运行，无需安装，适合 NAS 计划任务调用
## 🧩 项目组成
本项目整合了以下优秀开源项目：
| 组件 | 来源 | 说明 |
|------|------|------|
| **Aria2** | [aria2/aria2](https://github.com/aria2/aria2) | 核心下载引擎（命令行多协议下载工具） |
| **aria2.conf** | [P3TERX/aria2.conf](https://github.com/P3TERX/aria2.conf) | 高性能配置文件（针对 Windows 环境优化） |
| **AriaNg** | [mayswind/AriaNg](https://github.com/mayswind/AriaNg) | 现代化 Web 管理界面（All-in-One 单文件版） |
## 🔧 技术实现
### 配置优化
- **Aria2.conf**: 基于 P3TERX 的高性能配置，针对 Windows 环境进行了适配性调整
- **AriaNg**: 调整了默认参数，提供更友好的使用体验
### 管理工具
采用 **PowerShell 脚本**开发了集成管理工具，技术架构如下：
```
┌─────────────────────────────────────────┐
│          WinForms + WebBrowser          │
│    (Windows 原生 GUI + 嵌入式浏览器)     │
├─────────────────────────────────────────┤
│  ┌─────────────┐      ┌─────────────┐  │
│  │ 命令行输出  │      │  AriaNg 界面 │  │
│  │ (日志监控)  │      │  (操作面板)  │  │
│  └─────────────┘      └─────────────┘  │
└─────────────────────────────────────────┘
           │                    │
           └─────────┬──────────┘
                     ▼
              ┌──────────────┐
              │   Aria2c.exe │
              │  (后台运行)   │
              └──────────────┘
```
**核心功能：**
- 🖥️ **统一窗口** - 在一个界面中同时监控命令行输出和操作 AriaNg
- ⚙️ **后台运行** - Aria2 默认以守护进程方式运行，关闭窗口不中断下载
- 🔍 **自动捕获** - 再次打开工具时自动连接已运行的 Aria2 进程
## 📖 使用场景
### 场景一：NAS 计划任务启动
本项目最初的设计目的是在 NAS 机器上通过**计划任务**启动 Aria2c.exe，并开启 RPC 服务供远程下载使用。因此程序默认配置为**后台运行**模式，非常适合 24 小时开启的下载服务。
### 场景二：个人电脑轻量下载器
同时，它也是一个完美的**单机下载工具**：
- ✅ 极小体积 - 绿色便携，随用随开
- ✅ 一键启用 - 无需繁琐配置
- ✅ 日常使用 - 满足常规下载需求
## 🚀 快速开始
### 前置要求
- Windows 7 及以上版本
- PowerShell 3.0 及以上版本（Windows 7+ 自带）
### 使用步骤
1. **下载项目**
   ```bash
   git clone https://github.com/jiyun/Aria2-Manager.git
   ```
2. **一键启动**
   - 双击运行 `Aria2c_Manager.ps1` 脚本 如不运行可以可以自建批处理命令 `powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "F:\aria2\aria2c_manager.ps1"`
   - 首次运行会自动初始化 Aria2 配置
   - 程序启动后会自动在后台运行 Aria2c
3. **开始下载**
   - 在打开的管理界面中，使用 AriaNg 进行下载管理
   - 可随时关闭管理窗口，Aria2 将继续在后台运行
## 📝 配置说明
### 默认 RPC 设置
- **RPC 端口**: `6800`
- **RPC 密钥**: `P3TERX`（建议首次使用后修改）
- **RPC 地址**: `http://localhost:6800/jsonrpc`
### 下载目录
默认下载目录为当前目录下的 `Download` 文件夹，可在 `aria2.conf` 中修改：
```conf
dir=./Download
```
## 🔒 安全建议
⚠️ **重要提示**：如果需要在公网环境下使用，请务必：
1. 修改默认的 RPC 密钥（在 `aria2.conf` 中修改 `rpc-secret` 参数）
2. 配置防火墙规则，限制 RPC 端口的访问来源
3. 考虑使用反向代理（如 Nginx）添加 HTTPS 支持
## 📚 参考文档
| 项目 | 链接 |
|------|------|
| **本项目地址** | [GitHub](https://github.com/jiyun/Aria2-Manager) |
| **Aria2 官方文档** | [GitHub](https://github.com/aria2/aria2) |
| **AriaNg 官方文档** | [GitHub](https://github.com/mayswind/AriaNg) |
| **aria2.conf 配置说明** | [GitHub](https://github.com/P3TERX/aria2.conf) |
## 🤝 致谢
感谢以下开源项目的作者：
- **Aria2** - Tatsuhiro Tsujikawa
- **aria2.conf** - [P3TERX](https://github.com/P3TERX)
- **AriaNg** - [mayswind](https://github.com/mayswind)
- 本项目的脚本代码参考各种（豆包、智谱清言、千问等）大模型输出的建议制作而成。
## 📄 许可证
本项目遵循各组件的原有许可证。Aria2 使用 GPL-2.0 许可证，AriaNg 使用 MIT 许可证。
---
**💡 小贴士**: 如果你是第一次使用 Aria2，推荐先浏览 [AriaNg 官方文档](https://github.com/mayswind/AriaNg) 了解界面操作，再根据需要调整 `aria2.conf` 中的配置参数。
