# EM Task

[![GitHub Stars](https://img.shields.io/github/stars/EmericLee/emtask.svg)](https://github.com/EmericLee/emtask)
[![GitHub License](https://img.shields.io/github/license/EmericLee/emtask.svg)](https://github.com/EmericLee/emtask/blob/main/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/EmericLee/emtask.svg)](https://github.com/EmericLee/emtask/releases)

**Cross-platform Task Manager** — Sync with CalDAV / Nextcloud Tasks, built with Flutter.

[Features](#features) • [Download](#download) • [Development](#development) • [中文版本](README.md)

---

## 📋 Features

### Core Features

| Feature | Description |
|---|---|
| 📱 **Cross-platform** | One codebase runs on Windows / Linux / Android / UOS |
| 🔄 **CalDAV Sync** | Bi-directional sync with Nextcloud Tasks and other CalDAV services |
| 🌳 **Task Tree** | Parent-child hierarchy (RELATED-TO), folding, drag-and-drop, one-click subtask creation |
| 🏷️ **Tag System** | Flexible tag management with quick filtering |
| 📄 **PDF Export** | One-click export task list to PDF with built-in Chinese fonts |
| 💾 **Offline Cache** | Local SQLite database for offline access |

### Sync Features

| Feature | Description |
|---|---|
| 🔄 **Incremental Sync** | Based on sync-token for efficient delta pulls |
| ⏱️ **Auto Sync** | Configurable intervals (5/10/15/30 minutes) with intelligent triggers |
| 📊 **Sync Status** | Real-time display of pending upload/download count, last sync time |
| 🔌 **Connection Test** | One-click CalDAV server connection test |
| 📝 **Sync Log** | Detailed sync logs with popup viewer and copy support |

### UI/UX Features

| Feature | Description |
|---|---|
| 🎨 **Multiple Themes** | 9 preset colors (Forest Green, Ocean Blue, Indigo, Violet, Rose, Sunset Orange, Amber, Teal, Slate) with Material 3 dynamic color |
| ⭐ **Priority Stars** | Red solid for high, blue hollow for medium/low, gray for none |
| 📅 **Smart Filtering** | Filter by due date range, priority, status, tags |
| 📋 **In-place Editing** | Task details editable without popups |
| 🎯 **Task Status** | Three states: In Progress / Completed / Cancelled with visual progress bar |
| ✨ **Exit Animation** | Smooth highlight-and-fade animation when tasks are filtered out |

### Platform Support

| Platform | Description |
|---|---|
| 🐉 **UOS** | Specially adapted for UOS (ARM64), built with Debian 10 container for GLIBC 2.28 compatibility |
| 🖥️ **Desktop** | NavigationRail sidebar, mouse wheel acceleration, drag-and-drop task reordering |
| 📱 **Mobile** | Responsive layout for phones and tablets |

---

## 📥 Download

### From Releases

Download the version for your platform from [GitHub Releases](https://github.com/EmericLee/emtask/releases):

| Platform | Format | Description |
|---|---|---|
| Windows | `.zip` | Extract and run `em_task.exe` |
| Linux x86_64 | `.AppImage` | Run directly, no installation required |
| UOS / ARM64 | `.AppImage` | For UOS, Kylin and other Chinese Linux distributions |
| Android | `.apk` | Install directly |

### First Use

1. **Configure Sync**: Open "Sync" page, enter CalDAV server URL, username, password
2. **Test Connection**: Click "Test Connection" to verify server configuration
3. **Select Calendars**: Open "Calendars" page to select which calendars to sync
4. **Start Using**: Switch to "Tasks" page and start managing your tasks

### Sync Configuration

| Setting | Description |
|---|---|
| Server URL | CalDAV server URL (e.g., `https://your-server.com/remote.php/dav`) |
| Username | CalDAV account username |
| Password | CalDAV account password |
| Trust Certificate | Enable to trust self-signed certificates (testing only) |
| Sync Interval | Auto-sync interval (5/10/15/30 minutes) |

### Task Management

| Action | Description |
|---|---|
| Create Task | Click "New Task" button at the top of task list |
| Edit Task | Click task bar to enter details page, edit in-place |
| Create Subtask | Click "Add Subtask" in task details |
| Drag to Reorder | Drag task bar to adjust order |
| Mark Complete | Click checkbox on the left of task bar |
| Export PDF | Select "Export PDF" from the three-dot menu |

---

## 🛠️ Development

### Environment Requirements

| Tool | Version | Description |
|---|---|---|
| Flutter SDK | 3.32.5+ | Cross-platform UI framework |
| Dart SDK | 3.8.0+ | Programming language |
| Git | 2.30+ | Version control |

### Project Structure

```
em_task/
├── lib/
│   ├── main.dart                # App entry
│   ├── app.dart                 # Root Widget
│   ├── core/                    # Core modules
│   │   ├── constants/           # Constants
│   │   ├── errors/              # Error handling
│   │   ├── theme/               # Theming (9 presets + Material 3)
│   │   └── utils/               # Utilities (logging, platform info)
│   ├── data/                    # Data layer
│   │   ├── database/            # Drift database (SQLite)
│   │   ├── datasources/         # CalDAV datasource
│   │   ├── repositories/        # Repository implementations
│   │   └── settings/            # Settings storage
│   ├── domain/                  # Domain layer
│   │   ├── entities/            # Entities (Task, Calendar, freezed)
│   │   └── repositories/        # Repository interfaces
│   ├── features/                # Feature modules
│   │   ├── tasks/               # Task management (list/detail/PDF)
│   │   ├── calendars/           # Calendar management
│   │   ├── sync/                # Sync management (includes diagnostics)
│   │   └── settings/            # Settings page
│   └── router/                  # Routing (go_router)
├── assets/
│   └── fonts/                   # Chinese fonts (for PDF export)
├── .github/workflows/           # CI/CD configuration
│   └── build_auto.yml           # Auto-build workflow
├── release.dart                 # Release script
├── pubspec.yaml                 # Project configuration
└── README.md
```

### Quick Start

```bash
# 1. Clone repository
git clone https://github.com/EmericLee/emtask.git
cd em_task

# 2. Install dependencies
flutter pub get

# 3. Generate code (freezed / json_serializable / drift)
dart run build_runner build --delete-conflicting-outputs

# 4. Run the app
flutter run -d windows    # Windows
flutter run -d linux      # Linux
flutter run -d chrome     # Web
flutter run -d android    # Android
```

### Code Generation

This project uses `freezed`, `json_serializable`, `drift_dev` for code generation:

```bash
# Watch for changes and auto-generate
dart run build_runner watch --delete-conflicting-outputs

# One-time generation
dart run build_runner build --delete-conflicting-outputs
```

### Build & Release

```bash
# Build for each platform
flutter build windows --release    # Windows
flutter build linux --release      # Linux
flutter build apk --release        # Android
flutter build web --release        # Web
flutter build macos --release      # macOS
```

### Automated Release (GitHub Actions)

This project uses GitHub Actions for automated builds and releases.

#### Trigger Conditions

- **Push Tag**: `git push origin v0.1.1+2` — Auto builds and publishes to Release
- **Manual Trigger**: Click "Run workflow" on GitHub Actions page

#### Using the Release Script

[`release.dart`](release.dart) implements one-click release:

```bash
# 1. Install cider (semantic versioning tool)
dart pub global activate cider

# 2. Windows PATH configuration
$env:Path += ";$env:USERPROFILE\AppData\Local\Pub\Cache\bin"

# 3. Execute release
dart run release.dart patch   # Patch +1 (0.1.0 → 0.1.1)
dart run release.dart minor   # Minor +1 (0.1.0 → 0.2.0)
dart run release.dart major   # Major +1 (0.1.0 → 1.0.0)
dart run release.dart build   # Build number +1 (0.1.0+1 → 0.1.0+2)
```

The script automatically:
1. Updates version in `pubspec.yaml`
2. Creates Git commit (`Release version vX.Y.Z+N`)
3. Creates Git tag (e.g., `v0.1.1+2`)
4. Pushes to remote repository
5. Triggers GitHub Actions auto-build

### 🐉 UOS Adaptation

Adaptation for UOS (ARM64):

1. **GitHub ARM Runner**: `runs-on: ubuntu-24.04-arm`
2. **Debian 10 Container**: UOS is based on Debian 10 with GLIBC 2.28. Use same container for binary compatibility:
   ```yaml
   container:
     image: arm64v8/debian:buster
   ```
3. **Archive Sources**: Debian 10 EOL, switch to archive sources
4. **Manual Flutter Installation**: Official `subosito/flutter-action` has compatibility issues in ARM containers, use git clone instead
5. **AppImage Packaging**: Use `linuxdeploy` to collect dependencies (GTK, libc, etc.)

### Commit Message Convention

| Prefix | Purpose |
|---|---|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation update |
| `refactor:` | Refactoring |
| `chore:` | Build/tools |

---

## 📄 License

MIT License — See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [UniMark](https://github.com/disminde/UniMark) — UOS adaptation and CI/CD reference
- [Flutter](https://flutter.dev) — Cross-platform UI framework
- [Riverpod](https://riverpod.dev) — State management
- [Drift](https://drift.simonbinder.eu) — Type-safe SQLite ORM
