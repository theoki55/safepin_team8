// コミュニティの解決(URL固定 + 設定切替)を担うサービス。
//
// 優先順位:
//   1. URLパラメータ ?c=xxx (最優先。QR/チラシ配布で地域を固定)
//   2. shared_preferences の保存値(前回の手動切替)
//   3. 既定コミュニティ(kDefaultCommunityId)
//
// 起動後に設定画面から切り替えた場合は保存値が更新され、
// 以降はそちらが優先される(URLを再度開かない限り)。

import '../models/community.dart';
import '../utils/communities.dart';
import 'settings_service.dart';

class CommunityService {
  final SettingsService _settings;

  CommunityService(this._settings);

  /// 起動時に有効化するコミュニティを解決する。
  Future<Community> resolveInitial() async {
    // 1. URLパラメータ最優先
    final fromUrl = _communityIdFromUrl();
    if (isValidCommunityId(fromUrl)) {
      // URL指定は保存値としても記録し、以降の切替の起点にする。
      await _settings.saveCommunityId(fromUrl!);
      return communityById(fromUrl);
    }

    // 2. 保存値を復元
    final saved = await _settings.loadCommunityId();
    if (isValidCommunityId(saved)) {
      return communityById(saved);
    }

    // 3. 既定
    return communityById(kDefaultCommunityId);
  }

  /// URLの ?c= からコミュニティIDを取得(なければ null)。
  String? _communityIdFromUrl() {
    try {
      final c = Uri.base.queryParameters['c'];
      if (c != null && c.trim().isNotEmpty) return c.trim();
    } catch (_) {
      // Web以外やパース失敗時は無視。
    }
    return null;
  }

  /// コミュニティを切り替えて保存する。
  Future<void> persist(String communityId) async {
    if (isValidCommunityId(communityId)) {
      await _settings.saveCommunityId(communityId);
    }
  }
}
