import 'package:flutter/material.dart';

/// 应用主题配置（Material 3）。
///
/// 支持多个预设种子色，配合明暗模式生成主题。
class AppTheme {
  const AppTheme._();

  /// 预设主题种子色列表。
  static const List<AppThemePreset> presets = [
    AppThemePreset(id: 'forest', name: '森林绿', seedColor: Color(0xFF2E7D32)),
    AppThemePreset(id: 'ocean', name: '海洋蓝', seedColor: Color(0xFF0277BD)),
    AppThemePreset(id: 'indigo', name: '靛青', seedColor: Color(0xFF3F51B5)),
    AppThemePreset(id: 'violet', name: '紫罗兰', seedColor: Color(0xFF6A1B9A)),
    AppThemePreset(id: 'rose', name: '玫红', seedColor: Color(0xFFAD1457)),
    AppThemePreset(id: 'sunset', name: '日暮橙', seedColor: Color(0xFFE65100)),
    AppThemePreset(id: 'amber', name: '琥珀', seedColor: Color(0xFFFF8F00)),
    AppThemePreset(id: 'teal', name: '青碧', seedColor: Color(0xFF00695C)),
    AppThemePreset(id: 'slate', name: '石板灰', seedColor: Color(0xFF455A64)),
  ];

  /// 默认主题 id。
  static const defaultPresetId = 'forest';

  /// 根据 id 查找预设。
  static AppThemePreset presetById(String? id) {
    if (id == null) return presets.first;
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.first,
    );
  }

  static ThemeData light({String? presetId}) {
    final p = presetById(presetId);
    final scheme = ColorScheme.fromSeed(
      seedColor: p.seedColor,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark({String? presetId}) {
    final p = presetById(presetId);
    final scheme = ColorScheme.fromSeed(
      seedColor: p.seedColor,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// 主题预设。
class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.name,
    required this.seedColor,
  });

  /// 唯一标识（用于持久化）
  final String id;

  /// 显示名称
  final String name;

  /// 种子色
  final Color seedColor;
}
