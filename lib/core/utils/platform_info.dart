import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// 平台信息工具。
///
/// 统一封装当前运行平台判断，便于在 UI 与业务逻辑中区分桌面 / 移动 / Web。
class PlatformInfo {
  const PlatformInfo._();

  static bool get isWeb => kIsWeb;

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  static bool get isWindows => !kIsWeb && Platform.isWindows;

  static bool get isLinux => !kIsWeb && Platform.isLinux;

  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// 是否为桌面平台（Windows / macOS / Linux / UOS）
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  /// 是否为移动平台
  static bool get isMobile => isAndroid || isIOS;

  /// UOS 基于 Linux，桌面行为与 Linux 一致
  static bool get isUOSLike => isLinux;

  /// 当前平台可读名称
  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }
}
