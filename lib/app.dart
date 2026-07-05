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
    return MaterialApp.router(
      title: 'EM Task',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(presetId: themeState.presetId),
      darkTheme: AppTheme.dark(presetId: themeState.presetId),
      themeMode: themeState.themeMode,
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
