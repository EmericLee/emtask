import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/calendars/calendars_page.dart';
import '../features/settings/settings_page.dart';
import '../features/sync/sync_page.dart';
import '../features/tasks/task_detail_page.dart';
import '../features/tasks/task_page.dart';

/// 路由配置 Provider。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/tasks',
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) => _AppScaffold(
          location: state.uri.toString(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/tasks',
            name: 'tasks',
            builder: (context, state) => const TaskPage(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'taskDetail',
                builder: (context, state) =>
                    TaskDetailPage(taskId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/calendars',
            name: 'calendars',
            builder: (context, state) => const CalendarsPage(),
          ),
          GoRoute(
            path: '/sync',
            name: 'sync',
            builder: (context, state) => const SyncPage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});

/// 主框架：侧边导航栏 + 内容区。
class _AppScaffold extends StatefulWidget {
  const _AppScaffold({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<_AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<_AppScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  String? _lastTopRoute;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.value = 1.0; // 首次显示无需动画
    _lastTopRoute = _topRoute(widget.location);
  }

  @override
  void didUpdateWidget(_AppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = _topRoute(widget.location);
    if (_lastTopRoute != current) {
      _controller.forward(from: 0.0);
    }
    _lastTopRoute = current;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 提取顶级路由路径（同功能区内的子路由切换不触发动画）。
  String _topRoute(String location) {
    final parts = location.split('/');
    if (parts.length >= 2) return '/${parts[1]}';
    return location;
  }

  @override
  Widget build(BuildContext context) {
    final index = _selectedIndex(widget.location);
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(_pathForIndex(i)),
            extended: MediaQuery.of(context).size.width > 1100,
            minWidth: 36,
            minExtendedWidth: 140,
            selectedLabelTextStyle: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            unselectedLabelTextStyle: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: Text('任务'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: Text('日历'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sync_outlined),
                selectedIcon: Icon(Icons.sync),
                label: Text('同步'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          // 内容区：切换功能页时从右侧滑入
          Expanded(
            child: SlideTransition(
              position: _slide,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/tasks')) return 0;
    if (location.startsWith('/calendars')) return 1;
    if (location.startsWith('/sync')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  String _pathForIndex(int i) => switch (i) {
        0 => '/tasks',
        1 => '/calendars',
        2 => '/sync',
        3 => '/settings',
        _ => '/tasks',
      };
}
