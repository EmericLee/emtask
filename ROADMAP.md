# EM Task 开发路线图

跨平台任务管理器，支持 CalDAV / Nextcloud Tasks 同步，覆盖 Android、iOS、Linux/UOS、macOS、Windows。

## 技术栈

| 层次 | 选型 |
|------|------|
| UI | Flutter 3.x · Material 3 |
| 状态管理 | Riverpod 2.x |
| 路由 | go_router |
| 本地存储 | Drift (SQLite) |
| 网络/协议 | http + xml（CalDAV/WebDAV） |
| 序列化 | 自研 iCalendar VTODO 序列化器 |
| 模型 | freezed + json_serializable |
| 桌面窗口 | window_manager |

## 架构分层

```
lib/
├── main.dart                      入口（窗口初始化）
├── app.dart                       MaterialApp.router
├── core/                          基础设施
│   ├── constants/                 全局常量
│   ├── errors/                    Failure 体系
│   ├── theme/                     Material 3 主题
│   └── utils/                     平台判断等工具
├── domain/                        领域层（纯 Dart，无依赖）
│   ├── entities/                  Task / Calendar / 枚举
│   └── repositories/              仓储抽象接口
├── data/                          数据层
│   ├── datasources/caldav/        CalDAV 客户端 + iCal 序列化
│   ├── database/                  Drift 数据库 + 表定义
│   ├── repositories/              仓储实现
│   ├── settings/                  账户存储
│   └── providers.dart             Riverpod providers
├── features/                      功能模块（UI + 局部状态）
│   ├── tasks/                     任务列表 / 详情
│   ├── calendars/                 日历管理
│   ├── sync/                      同步状态
│   └── settings/                  账户配置
└── router/                        路由配置
```

## 已完成（v0.1 骨架）

- [x] 多平台工程脚手架（android/ios/linux/macos/windows）
- [x] 依赖配置与 lint 规则
- [x] 分层目录结构
- [x] 领域实体：Task、Calendar、TaskStatus、TaskPriority
- [x] 仓储抽象：TaskRepository / CalendarRepository / SyncRepository
- [x] CalDAV 客户端：PROPFIND / REPORT / GET / PUT / DELETE
- [x] iCalendar VTODO 序列化器（解析 + 生成 + 行折叠 + TEXT 转义）
- [x] Drift 数据库：Calendars / Tasks 表 + dirty/deleted 离线追踪
- [x] 仓储实现 + Riverpod providers
- [x] 同步引擎：push / pull / 完整同步 + ctag 增量判断
- [x] UI 骨架：任务列表、详情/编辑、日历管理、同步状态、设置
- [x] 桌面端 NavigationRail 自适应布局
- [x] Linux/UOS 窗口标题与 GTK 集成
- [x] Nextcloud 实测联调（认证、ctag、ETag、sync-collection 增量同步）
- [x] 子任务（parentUid + RELATED-TO 树形展示、拖拽排序、一键创建）

## 待开发（按优先级）

### P0 - 核心可用性
- [x] Nextcloud 实测联调（认证、ctag、ETag 乐观并发）
- [ ] 任务排序与筛选（按截止/优先级/状态/日历）
- [ ] 任务搜索
- [x] 子任务（RELATED-TO 树形展示）
- [ ] 通知（截止时间提醒，flutter_local_notifications）
- [ ] 冲突处理策略（远端优先 / 本地优先 / 手动合并 UI）

### P1 - 体验增强
- [ ] Material 3 动态配色（ColorScheme.fromImageProvider）
- [ ] 亮/暗主题切换
- [ ] 国际化（zh/en，flutter_localizations + arb）
- [ ] 拖拽排序、滑动完成/删除
- [ ] 日历颜色标识与筛选
- [ ] 标签/分类管理
- [ ] 任务附件（Nextcloud 评论 / 文件关联）

### P2 - 高级功能
- [ ] 多账户支持（当前仅单账户）
- [ ] WebDAV sync-token 增量同步（替代全量 ctag）
- [ ] 后台定时同步（workmanager / android background_fetch）
- [ ] VEVENT 日历事件只读展示
- [ ] 导入/导出 .ics 文件
- [ ] 任务模板
- [ ] 统计与可视化（本周完成数、延期率）

### P3 - 工程化
- [ ] 单元测试（ical_serializer / caldav_client / repositories）
- [ ] 集成测试（模拟 Nextcloud 服务端）
- [ ] CI/CD（GitHub Actions：analyze + test + build）
- [ ] 应用图标与启动屏（flutter_launcher_icons）
- [ ] 应用签名与打包（Linux deb/rpm、Windows msi、macOS dmg）
- [ ] UOS 适配验证（统信应用商店上架规范）
- [ ] 安全存储（flutter_secure_storage 替换明文密码）
- [ ] 自签名证书支持（HttpClient badCertificateCallback）

## CalDAV 同步流程

```
┌─────────────┐     ┌──────────────┐     ┌───────────────┐
│  UI 操作    │────▶│ TaskRepo     │────▶│  AppDatabase  │
│ (创建/编辑) │     │ (mark dirty) │     │ dirty=true    │
└─────────────┘     └──────────────┘     └───────────────┘
                                               │
                                               ▼
┌─────────────┐     ┌──────────────┐     ┌───────────────┐
│  SyncPage   │◀────│ SyncRepo     │◀────│ getDirty()    │
│ (状态展示)  │     │ push/pull    │     └───────────────┘
└─────────────┘     └──────┬───────┘
                           │
            ┌──────────────┴──────────────┐
            ▼                             ▼
     ┌─────────────┐              ┌───────────────┐
     │ CalDavClient│              │ IcalSerializer│
     │ PUT/DELETE  │              │ Task↔VTODO    │
     └──────┬──────┘              └───────────────┘
            │
            ▼
     ┌─────────────┐
     │ Nextcloud   │
     │ Tasks       │
     └─────────────┘
```

## 平台打包命令

```bash
# Windows
flutter build windows --release

# Linux / UOS
flutter build linux --release

# macOS
flutter build macos --release

# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ipa --release
```

## Nextcloud 配置要点

1. 服务端启用 CalDAV 应用
2. 用户在「安全」设置生成应用密码（非登录密码）
3. 应用密码填入 EM Task 设置页
4. UOS 内网部署需开启「信任自签名证书」选项

## 开发约定

- 严格分层：UI 只依赖 domain 抽象 + Riverpod provider，不直接访问 data 实现
- 不可变模型：所有实体用 freezed，变更通过 copyWith
- 离线优先：所有写操作先入库标记 dirty，同步在后台异步执行
- 响应式：UI 通过 StreamProvider 订阅数据库变化
- 错误处理：data 层抛异常，domain 层转 Failure，UI 层展示 SnackBar
