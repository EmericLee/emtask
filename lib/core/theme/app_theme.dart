import 'package:flutter/material.dart';

/// 应用主题配置（Material 3）。
///
/// 支持多个预设种子色，配合明暗模式生成主题。
class AppTheme {
  const AppTheme._();

  /// 预设主题种子色列表，按明度分三类：
  ///
  /// 1. **浅色类**（[AppThemePreset.brightness] = [Brightness.light]）：
  ///    强制浅色主题，高明度、清新明亮，不受全局模式影响。
  /// 2. **中色类**（brightness = null）：跟随全局明暗模式，中等明度与饱和度。
  /// 3. **深色类**（brightness = [Brightness.dark]）：强制深色主题，夜色风格。
  static const List<AppThemePreset> presets = [
    // 浅色类：强制浅色，明亮清新
    AppThemePreset(
        id: 'sky', name: '天空蓝', seedColor: Color(0xFF42A5F5), brightness: Brightness.light),
    AppThemePreset(
        id: 'meadow', name: '草地绿', seedColor: Color(0xFF66BB6A), brightness: Brightness.light),
    AppThemePreset(
        id: 'blossom', name: '桃花粉', seedColor: Color(0xFFEC407A), brightness: Brightness.light),
    // 中色类：跟随全局明暗模式，背景为带色调的中灰
    AppThemePreset(id: 'forest', name: '森林绿', seedColor: Color(0xFF2E7D32)),
    AppThemePreset(id: 'ocean', name: '海洋蓝', seedColor: Color(0xFF0277BD)),
    AppThemePreset(id: 'rose', name: '玫红', seedColor: Color(0xFFAD1457)),
    AppThemePreset(id: 'slate', name: '石板灰', seedColor: Color(0xFF455A64)),
    // 深色类：强制深色，夜色风格
    AppThemePreset(
        id: 'midnight', name: '夜色', seedColor: Color(0xFF212121), brightness: Brightness.dark),
    AppThemePreset(
        id: 'cosmos', name: '深空', seedColor: Color(0xFF1A237E), brightness: Brightness.dark),
    AppThemePreset(
        id: 'amethyst', name: '暗夜紫', seedColor: Color(0xFF4A148C), brightness: Brightness.dark),
    AppThemePreset(
        id: 'obsidian', name: '黑曜', seedColor: Color(0xFF263238), brightness: Brightness.dark),
  ];

  /// 默认主题 id。
  static const defaultPresetId = 'forest';

  /// 浅色类预设（强制浅色）。
  static List<AppThemePreset> get lightPresets =>
      presets.where((p) => p.forceLight).toList();

  /// 中色类预设（跟随全局明暗模式）。
  static List<AppThemePreset> get midPresets =>
      presets.where((p) => !p.forceLight && !p.forceDark).toList();

  /// 深色类预设（强制深色）。
  static List<AppThemePreset> get darkPresets =>
      presets.where((p) => p.forceDark).toList();

  /// 根据 id 查找预设。
  static AppThemePreset presetById(String? id) {
    if (id == null) return presets.first;
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.first,
    );
  }

  /// 生成预设指定亮度下的 [ColorScheme]。
  ///
  /// - 中色类（brightness = null）在浅色模式下使用中灰调背景
  ///   （surface 系列向中灰混合），区别于浅色类的白底；
  ///   深色模式下使用标准 fromSeed。
  /// - 浅色类、深色类使用标准 fromSeed。
  static ColorScheme schemeFor(AppThemePreset preset, Brightness brightness) {
    if (preset.brightness == null && brightness == Brightness.light) {
      return _midScheme(preset.seedColor);
    }
    return ColorScheme.fromSeed(
      seedColor: preset.seedColor,
      brightness: brightness,
    );
  }

  /// 中色调 ColorScheme：在 fromSeed(light) 基础上将 surface 系列向
  /// **带色调的中灰**混合，使背景呈中灰色调（明度介于浅色类的白与深色类的深之间）。
  ///
  /// 目标色由种子色经 HSL 调整而来（降明度至 0.5、饱和度减半），因此每个中色
  /// 预设的背景都带有自身种子色的色调（如绿调灰、蓝调灰），而非千篇一律的纯灰。
  /// primary/secondary 等强调色保持种子色特征，仅调整背景明度与色调。
  static ColorScheme _midScheme(Color seedColor) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    // 由种子色生成带色调的中灰目标：保留色相，明度降至 0.5，饱和度减半
    final hsl = HSLColor.fromColor(seedColor);
    final midTone = hsl
        .withSaturation(hsl.saturation * 0.5)
        .withLightness(0.5)
        .toColor();
    const t = 0.42;
    return base.copyWith(
      surface: Color.lerp(base.surface, midTone, t),
      surfaceDim: Color.lerp(base.surfaceDim, midTone, t),
      surfaceBright: Color.lerp(base.surfaceBright, midTone, t * 0.5),
      surfaceContainerLowest: Color.lerp(base.surfaceContainerLowest, midTone, t * 0.6),
      surfaceContainerLow: Color.lerp(base.surfaceContainerLow, midTone, t),
      surfaceContainer: Color.lerp(base.surfaceContainer, midTone, t),
      surfaceContainerHigh: Color.lerp(base.surfaceContainerHigh, midTone, t),
      surfaceContainerHighest: Color.lerp(base.surfaceContainerHighest, midTone, t),
    );
  }

  static ThemeData light({String? presetId}) {
    final p = presetById(presetId);
    return _base(schemeFor(p, Brightness.light));
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
      // 跨平台中文字体回退链：各平台优先使用系统字体（显示效果更好），
      // 覆盖主流 Linux 发行版预装字体，最后回退到打包的 NotoSansSC 兜底。
      fontFamilyFallback: const [
        'PingFang SC',          // macOS / iOS
        'Microsoft YaHei',      // Windows
        'Microsoft YaHei UI',   // Windows（UI 变体）
        'Noto Sans CJK SC',     // Linux（Ubuntu / UOS 思源黑体）
        'Source Han Sans CN',   // Linux（思源黑体 CN 命名）
        'Source Han Sans SC',   // Linux（思源黑体 SC 命名）
        'WenQuanYi Micro Hei',  // Linux（文泉驿微米黑）
        'WenQuanYi Zen Hei',    // Linux（文泉驿正黑）
        'Droid Sans Fallback',  // Android / 嵌入式 Linux
        'NotoSansSC',           // 打包字体（UOS 等兜底）
      ],
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
    this.brightness,
  });

  /// 唯一标识（用于持久化）
  final String id;

  /// 显示名称
  final String name;

  /// 种子色
  final Color seedColor;

  /// 强制亮度：
  /// - [Brightness.light]：强制浅色主题（浅色类）
  /// - [Brightness.dark]：强制深色主题（深色类）
  /// - null：跟随全局明暗模式（中色类）
  final Brightness? brightness;

  /// 是否为强制浅色预设。
  bool get forceLight => brightness == Brightness.light;

  /// 是否为强制深色预设。
  bool get forceDark => brightness == Brightness.dark;
}
