/// 应用入口。
///
/// 负责初始化窗口管理器（桌面端）、绑定 Flutter 引擎并启动 [ProviderScope]。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/utils/platform_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Linux渲染优化：通过 my_application.cc 在启动时设置环境变量
  // FLUTTER_RENDERER=skia，禁用Impeller后端，避免UOS等国产Linux
  // 发行版上因GPU驱动不完善导致的任务树闪烁问题。

  // 桌面端窗口初始化
  if (PlatformInfo.isDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 600),
      center: true,
      title: 'EM Task',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    const ProviderScope(
      child: EmTaskApp(),
    ),
  );
}
