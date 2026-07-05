import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/calendars/calendars_page.dart';
import '../features/diagnostics/diagnostics_page.dart';
import '../features/settings/settings_page.dart';
import '../features/sync/sync_page.dart';
import '../features/tasks/my_work_page.dart';
import '../features/tasks/task_detail_page.dart';
import '../features/tasks/task_list_page.dart';

/// 路由配置 Provider。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/my-work',
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) => _AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/my-work',
            name: 'myWork',
            builder: (context, state) => const MyWorkPage(),
          ),
          GoRoute(
            path: '/tasks',
            name: 'tasks',
            builder: (context, state) => const TaskListPage(),
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
            path: '/diagnostics',
            name: 'diagnostics',
            builder: (context, state) => const DiagnosticsPage(),
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
class _AppScaffold extends StatelessWidget {
  const _AppScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _selectedIndex(location);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(_pathForIndex(i)),
            extended: MediaQuery.of(context).size.width > 1100,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.work_outline),
                selectedIcon: Icon(Icons.work),
                label: Text('当前'),
              ),
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
                icon: Icon(Icons.bug_report_outlined),
                selectedIcon: Icon(Icons.bug_report),
                label: Text('诊断'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/my-work')) return 0;
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/calendars')) return 2;
    if (location.startsWith('/sync')) return 3;
    if (location.startsWith('/diagnostics')) return 4;
    if (location.startsWith('/settings')) return 5;
    return 0;
  }

  String _pathForIndex(int i) => switch (i) {
        0 => '/my-work',
        2 => '/calendars',
        3 => '/sync',
        4 => '/diagnostics',
        5 => '/settings',
        _ => '/tasks',
      };
}
