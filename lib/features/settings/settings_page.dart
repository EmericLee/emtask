import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/platform_info.dart';
import '../tasks/task_providers.dart';

/// 设置页：外观 + 任务列表显示 + 关于。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题选择
          Text('外观',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _ThemeSelector(ref: ref),
          const SizedBox(height: 24),
          // 任务列表显示设置
          Text('任务列表',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _OrphanModeSelector(ref: ref),
          const SizedBox(height: 12),
          // 日期字段是否显示时间
          SwitchListTile(
            title: const Text('日期字段显示时间'),
            subtitle: const Text('关闭时仅显示日期，开启后日期选择器可设置时分'),
            value: ref.watch(showTimeInDateFieldProvider),
            onChanged: (v) =>
                ref.read(showTimeInDateFieldProvider.notifier).state = v,
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              subtitle: Text('EM Task · 平台：${PlatformInfo.platformName}'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 主题选择器：预设色块网格 + 明暗模式切换。
class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final theme = Theme.of(context);

    final preset = themeState.preset;
    final forcedBrightness = preset.brightness; // null / light / dark

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 明暗模式：浅色/深色类预设强制固定亮度，隐藏切换器并提示；中色类跟随全局模式
        if (forcedBrightness != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Text('模式', style: theme.textTheme.labelLarge),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          preset.forceDark ? Icons.dark_mode : Icons.light_mode,
                          size: 18,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            preset.forceDark
                                ? '当前为深色风格配色，固定深色模式'
                                : '当前为浅色风格配色，固定浅色模式',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Text('模式', style: theme.textTheme.labelLarge),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 18),
                        label: Text('跟随系统'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode, size: 18),
                        label: Text('浅色'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode, size: 18),
                        label: Text('深色'),
                      ),
                    ],
                    selected: {themeState.themeMode},
                    onSelectionChanged: (s) => controller.setThemeMode(s.first),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text('配色', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        // 所有配色合在一起展示（浅色/中色/深色三类按列表顺序排列）
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in AppTheme.presets)
              _ColorChip(
                preset: p,
                selected: p.id == themeState.presetId,
                onTap: () => controller.setPreset(p.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// 标签过滤后孤儿任务的显示模式选择器。
class _OrphanModeSelector extends StatelessWidget {
  const _OrphanModeSelector({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(orphanDisplayModeProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Text('过滤孤儿任务', style: theme.textTheme.labelLarge),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<OrphanDisplayMode>(
                  segments: const [
                    ButtonSegment(
                      value: OrphanDisplayMode.tree,
                      icon: Icon(Icons.account_tree_outlined, size: 18),
                      label: Text('树状'),
                    ),
                    ButtonSegment(
                      value: OrphanDisplayMode.prefix,
                      icon: Icon(Icons.label_outline, size: 18),
                      label: Text('前缀'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) =>
                      ref.read(orphanDisplayModeProvider.notifier).state = s.first,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            mode == OrphanDisplayMode.tree
                ? '树状：向上追溯父任务链，保持完整树状结构。'
                : '前缀：孤儿任务提升为根，标题前显示父路径前缀。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}

/// 单个配色色块：展示该种子色生成的真实色板（primary、primaryContainer、
/// secondary、tertiary），让不同配色的区别直观可见，而非仅显示种子色圆点。
class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AppThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 预览亮度：浅色类强制 light，深色类强制 dark，中色类跟随当前主题。
    // 中色类通过 AppTheme.schemeFor 生成中灰调背景，预览与实际应用效果一致。
    final brightness =
        preset.brightness ?? Theme.of(context).brightness;
    final scheme = AppTheme.schemeFor(preset, brightness);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: preset.name,
        child: Container(
          width: 72,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 主色圆球（primary）
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(height: 8),
              // 色板条：primaryContainer / secondary / tertiary
              // 这三色在不同种子色之间差异明显，便于区分
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _swatch(scheme.primaryContainer),
                  const SizedBox(width: 4),
                  _swatch(scheme.secondary),
                  const SizedBox(width: 4),
                  _swatch(scheme.tertiary),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                preset.name,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatch(Color c) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
      ),
    );
  }
}
