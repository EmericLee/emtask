import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

/// 主题偏好持久化（基于 SharedPreferences）。
///
/// 存储：主题预设 id + 明暗模式（system/light/dark）。
class ThemeStorage {
  ThemeStorage(this._prefs);

  static const _keyPresetId = 'theme_preset_id';
  static const _keyThemeMode = 'theme_mode';

  final SharedPreferences _prefs;

  /// 当前主题预设 id（默认 forest）。
  String get presetId =>
      _prefs.getString(_keyPresetId) ?? AppTheme.defaultPresetId;

  /// 当前明暗模式（默认跟随系统）。
  ThemeMode get themeMode {
    final v = _prefs.getString(_keyThemeMode);
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> savePresetId(String id) =>
      _prefs.setString(_keyPresetId, id);

  Future<void> saveThemeMode(ThemeMode mode) {
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return _prefs.setString(_keyThemeMode, v);
  }
}
