import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'router/app_router.dart';

/// 应用根 Widget。
///
/// 使用 [MaterialApp.router] 接入 go_router，统一 Material 3 主题与本地化。
/// 主题（预设色 + 明暗模式）由 [themeControllerProvider] 控制，可在设置页切换。
class EmTaskApp extends ConsumerWidget {
  const EmTaskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeState = ref.watch(themeControllerProvider);
    // 浅色类预设强制浅色，深色类预设强制深色，中色类跟随全局模式。
    final preset = themeState.preset;
    final forcedLight = preset.forceLight;
    final forcedDark = preset.forceDark;
    return MaterialApp.router(
      title: 'EM Task',
      debugShowCheckedModeBanner: false,
      theme: forcedDark
          ? AppTheme.dark(presetId: themeState.presetId)
          : AppTheme.light(presetId: themeState.presetId),
      darkTheme: forcedLight
          ? AppTheme.light(presetId: themeState.presetId)
          : AppTheme.dark(presetId: themeState.presetId),
      themeMode: forcedDark
          ? ThemeMode.dark
          : (forcedLight ? ThemeMode.light : themeState.themeMode),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      routerConfig: router,
    );
  }
}
