// EM Task 发布脚本
//
// 使用方式：
//   dart run release.dart [type]
//   type: patch, minor, major, build
//
// 前置条件：
//   1. 安装 cider：
//      dart pub global activate cider
//   2. 配置 PATH（Windows）：
//      $env:Path += ";$env:USERPROFILE\AppData\Local\Pub\Cache\bin"
//   3. 在项目根目录运行此脚本
//
// 流程：
//   1. 检查 Git 工作区状态
//   2. 使用 cider 升级版本号（语义化版本）
//   3. 创建 Git commit 和 tag
//   4. 推送到远程仓库（push 代码 + push tags）
//   5. GitHub Actions 自动触发构建并发布 Release
//
// 示例：
//   dart run release.dart patch   # 0.1.0+1 → 0.1.1+2
//   dart run release.dart minor   # 0.1.0+1 → 0.2.0+2
//   dart run release.dart major   # 0.1.0+1 → 1.0.0+2
//   dart run release.dart build   # 0.1.0+1 → 0.1.0+2

// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  // 1. 解析参数
  final type = args.isNotEmpty ? args[0] : 'patch';
  final allowedTypes = ['patch', 'minor', 'major', 'build'];
  if (!allowedTypes.contains(type)) {
    print('❌ 错误: 无效的升级类型 "$type". 可选值: ${allowedTypes.join(', ')}');
    exit(1);
  }

  print('🚀 开始发布流程 (类型: $type)...');

  // 2. 检查 Git 工作区状态
  final status = runCommand('git', ['status', '--porcelain']);
  if (status.stdout.toString().trim().isNotEmpty) {
    print('🔄 Git 工作区不干净，自动添加所有更改。');
    runCommand('git', ['add', '.']);
  } else {
    print('✅ Git 工作区干净，继续发布流程...');
  }

  try {
    // 3. 使用 cider 升级版本号
    print('🔄 正在升级版本号...');
    if (type == 'build') {
      runCommand('dart', ['pub', 'global', 'run', 'cider', 'bump', 'build']);
    } else {
      runCommand('dart',
          ['pub', 'global', 'run', 'cider', 'bump', type, '--bump-build']);
    }

    // 4. 获取新版本号
    final versionResult =
        runCommand('dart', ['pub', 'global', 'run', 'cider', 'version']);
    final newVersion = versionResult.stdout.toString().trim();
    print('✅ 版本已更新为: $newVersion');

    // 5. Git 提交与打 Tag
    print('📦 提交代码并打 Tag...');
    runCommand('git', ['add', '.']);
    final commitMsg = 'Release version v$newVersion';
    runCommand('git', ['commit', '-m', commitMsg]);

    final tagName = 'v$newVersion';
    runCommand('git', ['tag', '-a', tagName, '-m', 'Release $tagName']);

    // 6. 推送到远程
    print('📤 推送到远程仓库...');
    runCommand('git', ['push']);
    runCommand('git', ['push', '--tags']);

    print('');
    print('🎉 发布完成！');
    print('👉 提交信息: $commitMsg');
    print('👉 Tag: $tagName');
    print('👉 GitHub Actions 将自动构建并发布 Release');
    print('👉 查看构建进度: https://github.com/${getRepoSlug()}/actions');
  } catch (e) {
    print('❌ 发生异常: $e');
    exit(1);
  }
}

/// 从 git remote 获取仓库的 owner/repo 字符串。
String getRepoSlug() {
  try {
    final result = runCommand(
        'git', ['config', '--get', 'remote.origin.url']);
    final url = result.stdout.toString().trim();
    // 支持 SSH (git@github.com:owner/repo.git) 和 HTTPS (https://github.com/owner/repo.git)
    final match = RegExp(r'github\.com[:/]([^/]+)/([^/]+?)(\.git)?$').firstMatch(url);
    if (match != null) {
      return '${match.group(1)}/${match.group(2)}';
    }
  } catch (_) {
    // 忽略
  }
  return 'your-username/em_task';
}

/// 辅助函数：运行 Shell 命令
ProcessResult runCommand(String command, List<String> args) {
  final result = Process.runSync(
    command,
    args,
    runInShell: true, // 关键：跨平台查找 PATH 中的命令
  );
  if (result.exitCode != 0) {
    print('❌ 执行命令失败: $command ${args.join(' ')}');
    print('错误输出: ${result.stderr}');
    throw Exception('Command failed');
  }
  return result;
}
