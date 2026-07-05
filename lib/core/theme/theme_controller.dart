import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../data/settings/theme_storage.dart';

/// 主题存储 Provider。
final themeStorageProvider = FutureProvider<ThemeStorage>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return ThemeStorage(prefs);
});

/// 主题状态：当前预设 + 明暗模式。
class ThemeState {
  const ThemeState({required this.presetId, required this.themeMode});

  final String presetId;
  final ThemeMode themeMode;

  AppThemePreset get preset => AppTheme.presetById(presetId);

  ThemeState copyWith({
    String? presetId,
    ThemeMode? themeMode,
  }) {
    return ThemeState(
      presetId: presetId ?? this.presetId,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

/// 主题控制器：读取/修改主题偏好，并持久化。
///
/// [storage] 为 null 时仅维护内存状态（用于初始化阶段）。
class ThemeController extends StateNotifier<ThemeState> {
  ThemeController({ThemeStorage? storage})
      : _storage = storage,
        super(ThemeState(
          presetId: storage?.presetId ?? AppTheme.defaultPresetId,
          themeMode: storage?.themeMode ?? ThemeMode.system,
        ));

  final ThemeStorage? _storage;

  Future<void> setPreset(String id) async {
    state = state.copyWith(presetId: id);
    await _storage?.savePresetId(id);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _storage?.saveThemeMode(mode);
  }
}

/// 主题控制器 Provider。
///
/// 注：当 [themeStorageProvider] 尚未加载完成时返回默认状态；
/// 加载完成后会自动重建以读取持久化值。
final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeState>((ref) {
  final storage = ref.watch(themeStorageProvider).valueOrNull;
  return ThemeController(storage: storage);
});
