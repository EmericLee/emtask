import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'caldav_account.freezed.dart';
part 'caldav_account.g.dart';

/// CalDAV 服务端账户配置。
///
/// Nextcloud 示例：
/// - [baseUrl] = https://cloud.example.com
/// - [username] = alice
/// - [password] = 应用密码（在 Nextcloud 安全设置中生成）
@freezed
class CalDavAccount with _$CalDavAccount {
  const factory CalDavAccount({
    /// 服务端基础地址（不含路径，如 https://cloud.example.com）
    required String baseUrl,

    /// 用户名
    required String username,

    /// 应用密码 / 密码
    required String password,

    /// 是否信任自签名证书（内网部署 / UOS 本地部署常用）
    @Default(false) bool trustSelfSignedCert,

    /// 显示名称
    String? displayName,
  }) = _CalDavAccount;

  factory CalDavAccount.fromJson(Map<String, dynamic> json) =>
      _$CalDavAccountFromJson(json);

  const CalDavAccount._();

  /// 清理后的 baseUrl：去掉常见的 Nextcloud 路径后缀。
  ///
  /// 用户可能误填 `https://cloud.example.com/remote.php/dav`，
  /// 这里统一去掉 `/remote.php/dav`、`/index.php` 等后缀，只保留根域名。
  String get sanitizedBaseUrl {
    var url = baseUrl;
    // 去掉末尾斜杠
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // 去掉常见的 Nextcloud 路径后缀
    for (final suffix in [
      '/remote.php/dav',
      '/remote.php/webdav',
      '/remote.php',
      '/index.php',
    ]) {
      if (url.toLowerCase().endsWith(suffix.toLowerCase())) {
        url = url.substring(0, url.length - suffix.length);
      }
    }
    return url;
  }

  /// Nextcloud 用户的 calendars 集合根 URL
  /// 例：https://cloud.example.com/remote.php/dav/calendars/alice/
  String get nextcloudCalendarsHome =>
      '$sanitizedBaseUrl/remote.php/dav/calendars/$username/';

  /// 构造 Basic 认证头值
  String get basicAuthHeader {
    final credentials = '$username:$password';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }
}
