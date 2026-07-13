# EM Task

[![GitHub Stars](https://img.shields.io/github/stars/EmericLee/emtask.svg)](https://github.com/EmericLee/emtask)
[![GitHub License](https://img.shields.io/github/license/EmericLee/emtask.svg)](https://github.com/EmericLee/emtask/blob/main/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/EmericLee/emtask.svg)](https://github.com/EmericLee/emtask/releases)

**跨平台任务管理器** — 支持 CalDAV / Nextcloud Tasks 同步，基于 Flutter 构建。

[Features](#features) • [特性](#-特性功能) • [Download](#download) • [下载](#-使用下载) • [Development](#development) • [开发](#-开发指南)

---

## English Summary

**EM Task** is a cross-platform task manager built with Flutter, supporting CalDAV / Nextcloud Tasks synchronization. It runs on Windows, Linux, Android, and UOS (Chinese Linux distribution).

### Key Features
- **Cross-platform**: Windows / Linux / Android / UOS
- **CalDAV Sync**: Bi-directional sync with Nextcloud Tasks
- **Task Tree**: Parent-child hierarchy, drag-and-drop, folding
- **PDF Export**: Built-in Chinese fonts, offline support
- **Multiple Themes**: 9 preset colors with Material 3 dynamic color

### Download
- GitHub Releases: https://github.com/EmericLee/emtask/releases

### Tech Stack
- Flutter 3.32.5 + Dart 3.8
- Riverpod state management
- Drift (SQLite) database
- go_router navigation

---

## 📋 特性功能

### 核心功能

| 功能 | 说明 |
|---|---|
| 📱 **跨平台支持** | 一套代码，Windows / Linux / Android / UOS 多端运行 |
| 🔄 **CalDAV 同步** | 支持 Nextcloud Tasks 等 CalDAV 服务，自动双向同步 |
| 🌳 **任务树管理** | 父子任务层级（RELATED-TO），支持折叠展开、拖拽排序、一键创建子任务 |
| 🏷️ **标签系统** | 灵活的标签管理，支持按标签快速筛选任务 |
| 📄 **PDF 导出** | 一键将任务清单导出为 PDF，中文字体内置，离线可用 |
| 💾 **离线缓存** | 本地 SQLite 数据库，断网时仍可查看和编辑 |

### 同步特性

| 特性 | 说明 |
|---|---|
| 🔄 **增量同步** | 基于 sync-token 实现增量拉取，减少网络请求 |
| ⏱️ **自动同步** | 可配置同步间隔（5/10/15/30分钟），智能触发策略 |
| 📊 **同步状态** | 实时显示待上传/下载数量、上次同步时间 |
| 🔌 **连接测试** | 一键测试 CalDAV 服务器连接状态 |
| 📝 **同步日志** | 详细的同步日志记录，支持弹窗查看和复制 |

### UI/UX 特性

| 特性 | 说明 |
|---|---|
| 🎨 **多主题** | 9 个预设主题色（森林绿、海洋蓝、靛青、紫罗兰、玫红、日暮橙、琥珀、青碧、石板灰），支持 Material 3 动态取色 |
| ⭐ **优先级五角星** | 高优先级红色实心、中/低优先级蓝色空心、无优先级灰色显示 |
| 📅 **智能过滤** | 支持按截止日期范围、优先级、状态、标签过滤任务 |
| 📋 **就地编辑** | 任务详情页支持就地编辑，无需弹窗，编辑体验流畅 |
| 🎯 **任务状态** | 进行中/完成/取消三种状态，可视化进度条 |
| ✨ **退出动画** | 任务过滤时的高亮淡出动画效果 |

### 平台适配

| 平台 | 说明 |
|---|---|
| 🐉 **UOS 系统** | 针对统信 UOS（ARM64）进行专门适配，使用 Debian 10 容器构建保证 GLIBC 2.28 兼容 |
| 🖥️ **桌面端优化** | 支持 NavigationRail 侧边栏导航、鼠标滚轮加速、任务条拖拽 |
| 📱 **移动端适配** | 响应式布局，适配手机和平板设备 |

---

## 📥 使用下载

### 从 Release 下载

从 [GitHub Releases](https://github.com/EmericLee/emtask/releases) 页面下载适合您平台的版本：

| 平台 | 下载格式 | 说明 |
|---|---|---|
| Windows | `.zip` | 解压后运行 `em_task.exe` |
| Linux x86_64 | `.AppImage` | 直接运行，无需安装 |
| UOS / ARM64 | `.AppImage` | 适用于统信 UOS、麒麟等国产系统 |
| Android | `.apk` | 直接安装 |

### 首次使用

1. **配置同步**：打开"同步"页面，填写 CalDAV 服务器地址、用户名、密码
2. **连接测试**：点击"连接测试"验证服务器配置是否正确
3. **同步日历**：在"日历"页面选择要同步的日历
4. **开始使用**：切换到"任务"页面开始管理任务

### 同步配置

| 配置项 | 说明 |
|---|---|
| 服务器地址 | CalDAV 服务器 URL（如 `https://your-server.com/remote.php/dav`） |
| 用户名 | CalDAV 账户用户名 |
| 密码 | CalDAV 账户密码 |
| 信任证书 | 启用后信任自签名证书（仅用于测试环境） |
| 同步间隔 | 自动同步的时间间隔（5/10/15/30分钟） |

### 任务管理

| 操作 | 说明 |
|---|---|
| 创建任务 | 点击任务列表顶部的"新建任务"按钮 |
| 编辑任务 | 点击任务条进入详情页，就地编辑各项内容 |
| 创建子任务 | 在任务详情页点击"添加子任务" |
| 拖拽排序 | 在任务列表中拖拽任务条调整顺序 |
| 标记完成 | 点击任务条左侧的复选框 |
| 导出 PDF | 在任务列表右上角三点菜单中选择"导出 PDF" |

---

## 🛠️ 开发指南

### 环境要求

| 工具 | 版本 | 说明 |
|---|---|---|
| Flutter SDK | 3.32.5+ | 跨平台 UI 框架 |
| Dart SDK | 3.8.0+ | 编程语言 |
| Git | 2.30+ | 版本控制 |

### 项目结构

```
em_task/
├── lib/
│   ├── main.dart                # 应用入口
│   ├── app.dart                 # App 根 Widget
│   ├── core/                    # 核心模块
│   │   ├── constants/           # 常量定义
│   │   ├── errors/              # 错误处理
│   │   ├── theme/               # 主题（9 预设色 + Material 3）
│   │   └── utils/               # 工具函数（日志、平台信息）
│   ├── data/                    # 数据层
│   │   ├── database/            # Drift 数据库（SQLite）
│   │   ├── datasources/         # CalDAV 数据源
│   │   ├── repositories/        # 仓储实现
│   │   └── settings/            # 设置存储
│   ├── domain/                  # 领域层
│   │   ├── entities/            # 实体（Task, Calendar, freezed）
│   │   └── repositories/        # 仓储接口
│   ├── features/                # 功能模块
│   │   ├── tasks/               # 任务管理（列表/详情/PDF 导出）
│   │   ├── calendars/           # 日历管理
│   │   ├── sync/                # 同步管理（含诊断功能）
│   │   ├── settings/            # 设置页
│   │   └── diagnostics/         # 诊断工具（已合并到同步页）
│   └── router/                  # 路由配置（go_router）
├── assets/
│   └── fonts/                   # 中文字体（PDF 导出用）
├── .github/workflows/           # CI/CD 配置
│   └── build_auto.yml           # 自动构建工作流
├── release.dart                 # 发布脚本
├── pubspec.yaml                 # 项目配置
└── README.md
```

### 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/EmericLee/emtask.git
cd em_task

# 2. 安装依赖
flutter pub get

# 3. 生成代码（freezed / json_serializable / drift）
dart run build_runner build --delete-conflicting-outputs

# 4. 运行项目
flutter run -d windows    # Windows
flutter run -d linux      # Linux
flutter run -d chrome     # Web
flutter run -d android    # Android
```

### 代码生成

本项目使用 `freezed`、`json_serializable`、`drift_dev` 进行代码生成：

```bash
# 监听文件变化，自动生成
dart run build_runner watch --delete-conflicting-outputs

# 一次性生成
dart run build_runner build --delete-conflicting-outputs
```

### 构建发布

```bash
# 各平台构建
flutter build windows --release    # Windows
flutter build linux --release      # Linux
flutter build apk --release        # Android
flutter build web --release        # Web
flutter build macos --release      # macOS
```

### 自动化发布（GitHub Actions）

本项目使用 GitHub Actions 实现自动化构建发布。

#### 触发条件

- **推送 Tag**：`git push origin v0.1.1+2` — 自动构建并发布到 Release
- **手动触发**：在 GitHub Actions 页面点击 "Run workflow"

#### 使用发布脚本

[`release.dart`](release.dart) 实现了一键发布流程：

```bash
# 1. 一次性安装 cider（语义化版本管理工具）
dart pub global activate cider

# 2. Windows 配置 PATH
$env:Path += ";$env:USERPROFILE\AppData\Local\Pub\Cache\bin"

# 3. 执行发布
dart run release.dart patch   # 修订版本 +1（0.1.0 → 0.1.1）
dart run release.dart minor   # 次版本 +1（0.1.0 → 0.2.0）
dart run release.dart major   # 主版本 +1（0.1.0 → 1.0.0）
dart run release.dart build   # 仅构建号 +1（0.1.0+1 → 0.1.0+2）
```

脚本执行后会自动：
1. 升级 `pubspec.yaml` 中的版本号
2. 创建 Git commit（信息：`Release version vX.Y.Z+N`）
3. 创建 Git tag（如 `v0.1.1+2`）
4. 推送到远程仓库
5. 触发 GitHub Actions 自动构建

### 🐉 UOS 适配说明

针对统信 UOS（ARM64）系统的适配方案：

1. **使用 GitHub ARM Runner**：`runs-on: ubuntu-24.04-arm`
2. **Debian 10 容器构建**：UOS 基于 Debian 10，GLIBC 版本为 2.28。使用相同版本的容器确保二进制兼容性：
   ```yaml
   container:
     image: arm64v8/debian:buster
   ```
3. **修复 EOL 源列表**：Debian 10 已停止维护，需切换到 archive 源
4. **手动安装 Flutter**：官方 `subosito/flutter-action` 在 ARM 容器内兼容性差，改为 git clone
5. **AppImage 打包**：使用 `linuxdeploy` 自动收集依赖（GTK、libc 等），生成自包含的可执行文件

### 提交信息规范

| 前缀 | 用途 |
|---|---|
| `feat:` | 新功能 |
| `fix:` | 修复问题 |
| `docs:` | 文档更新 |
| `refactor:` | 重构 |
| `chore:` | 构建/工具 |

---

## 📄 许可证

MIT License — 详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- [UniMark](https://github.com/disminde/UniMark) — UOS 适配和 CI/CD 方案参考
- [Flutter](https://flutter.dev) — 跨平台 UI 框架
- [Riverpod](https://riverpod.dev) — 状态管理
- [Drift](https://drift.simonbinder.eu) — 类型安全的 SQLite ORM
