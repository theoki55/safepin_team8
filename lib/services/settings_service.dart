import 'package:shared_preferences/shared_preferences.dart';

import '../models/enums.dart';

/// ユーザー設定(モード・投稿者名)を shared_preferences に保存する。
class SettingsService {
  static const _kMode = 'app_mode';
  static const _kAuthor = 'author_name';

  Future<AppMode> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    return AppMode.fromName(prefs.getString(_kMode) ?? AppMode.normal.name);
  }

  Future<void> saveMode(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, mode.name);
  }

  Future<String> loadAuthorName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAuthor) ?? '';
  }

  Future<void> saveAuthorName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAuthor, name);
  }
}
