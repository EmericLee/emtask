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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 明暗模式
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

/// 单个配色色块。
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
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Tooltip(
        message: preset.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: preset.seedColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: preset.seedColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 22)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              preset.name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outline,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
