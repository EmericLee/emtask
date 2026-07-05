import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../datasources/caldav/caldav_account.dart';

/// CalDAV 账户配置持久化（基于 SharedPreferences）。
///
/// 仅保存单个账户配置；密码明文存储是简化实现，生产环境建议使用
/// flutter_secure_storage。
class AccountStorage {
  AccountStorage(this._prefs);

  static const _keyAccount = 'caldav_account';

  final SharedPreferences _prefs;

  Future<CalDavAccount?> load() async {
    final json = _prefs.getString(_keyAccount);
    if (json == null) return null;
    return CalDavAccount.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> save(CalDavAccount account) async {
    await _prefs.setString(_keyAccount, jsonEncode(account.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(_keyAccount);
  }
}
