# EM Task

**跨平台任务管理器** — 支持 CalDAV / Nextcloud Tasks 同步，基于 Flutter 构建。

[特性](#-主要特性) • [下载](#-下载安装) • [构建发布](#-构建与发布) • [开发](#-开发指南) • [许可证](#-许可证)

## 📋 项目简介

**EM Task** 是一款基于 Flutter 开发的跨平台任务管理应用，支持通过 CalDAV 协议与 Nextcloud Tasks 等服务同步。无论在桌面端还是移动端，都能保持任务数据的一致性和实时性。

### 主要特性

| 特性 | 说明 |
|---|---|
| 📱 **跨平台** | 一套代码，Windows / Linux / Android / UOS 多端运行 |
| 🐉 **UOS 系统支持** | 针对统信 UOS（ARM64）进行专门适配，使用 Debian 10 容器构建保证 GLIBC 2.28 兼容 |
| 🔄 **CalDAV 同步** | 支持 Nextcloud Tasks 等 CalDAV 服务，自动双向同步 |
| 🌳 **任务树** | 支持父子任务层级，可折叠展开 |
| 🏷️ **标签过滤** | 按标签快速筛选任务 |
| 🎨 **多主题** | 9 个预设主题色（森林绿、海洋蓝等），支持 Material 3 动态取色 |
| 📄 **PDF 导出** | 一键将任务清单导出为 PDF（中文字体内置，离线可用） |
| 🔍 **过滤排序** | 支持隐藏已完成任务、按截止日期/优先级/手动排序 |
| 💾 **离线缓存** | 本地 SQLite 数据库，断网时仍可查看和编辑 |
| 🔄 **GitHub Actions CI** | 推送 Tag 自动构建并发布 Release |

## 📥 下载安装

从 [Releases](../../releases) 页面下载适合您平台的版本：

| 平台 | 下载格式 | 说明 |
|---|---|---|
| Windows | `.zip` | 解压后运行 `em_task.exe` |
| Linux x86_64 | `.AppImage` | 直接运行，无需安装 |
| UOS / ARM64 | `.AppImage` | 适用于统信 UOS、麒麟等国产系统 |
| Android | `.apk` | 直接安装 |

## 🚀 构建与发布

### 本地构建

```bash
# 安装依赖
flutter pub get

# 生成 freezed / json_serializable / drift 代码
dart run build_runner build --delete-conflicting-outputs

# 各平台构建
flutter build windows --release    # Windows
flutter build linux --release      # Linux
flutter build apk --release        # Android
flutter build web --release        # Web
flutter build macos --release      # macOS
```

### 自动化发布（GitHub Actions）

本项目使用 GitHub Actions 实现自动化构建发布，流程参照 [UniMark](https://github.com/disminde/UniMark) 项目的方案。

#### 工作流文件

[.github/workflows/build_auto.yml](.github/workflows/build_auto.yml) 定义了 4 个并行构建任务：

| Job | Runner | 产物 | 说明 |
|---|---|---|---|
| `build-uos` | `ubuntu-24.04-arm` + Debian 10 容器 | `em_task-uos-arm64.AppImage` | UOS / 国产 ARM 系统 |
| `build-linux-x86` | `ubuntu-latest` | `em_task-linux-x86_64.AppImage` | 标准 Linux x86_64 |
| `build-windows` | `windows-latest` | `em_task-windows-x64.zip` | Windows x64 |
| `build-android` | `ubuntu-latest` | `em_task-android.apk` | Android 通用 APK |

#### 触发条件

- **推送 Tag**：`git push origin v0.1.1+2` — 自动构建并发布到 Release
- **手动触发**：在 GitHub Actions 页面点击 "Run workflow"

#### 使用发布脚本

[`release.dart`](release.dart) 实现了一键发布流程（升级版本号 → 提交 → 打 Tag → 推送）：

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

## 🛠️ 开发指南

### 环境要求

| 工具 | 版本 | 说明 |
|---|---|---|
| Flutter SDK | 3.32.5+ | 跨平台 UI 框架 |
| Dart SDK | 3.11.0+ | 编程语言 |
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
│   │   ├── sync/                # 同步管理
│   │   ├── settings/            # 设置页
│   │   └── diagnostics/         # 诊断工具
│   └── router/                  # 路由配置（go_router）
├── assets/
│   └── fonts/                   # 中文字体（PDF 导出用）
├── .github/workflows/           # CI/CD 配置
│   └── build_auto.yml           # 自动构建工作流
├── release.dart                 # 发布脚本
├── pubspec.yaml                 # 项目配置
└── README.md
```

### 代码生成

本项目使用 `freezed`、`json_serializable`、`drift_dev` 进行代码生成：

```bash
# 监听文件变化，自动生成
dart run build_runner watch --delete-conflicting-outputs

# 一次性生成
dart run build_runner build --delete-conflicting-outputs
```

### 提交信息规范

| 前缀 | 用途 |
|---|---|
| `feat:` | 新功能 |
| `fix:` | 修复问题 |
| `docs:` | 文档更新 |
| `refactor:` | 重构 |
| `chore:` | 构建/工具 |

## 📄 许可证

MIT License — 详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- [UniMark](https://github.com/disminde/UniMark) — UOS 适配和 CI/CD 方案参考
- [Flutter](https://flutter.dev) — 跨平台 UI 框架
- [Riverpod](https://riverpod.dev) — 状态管理
- [Drift](https://drift.simonbinder.eu) — 类型安全的 SQLite ORM
