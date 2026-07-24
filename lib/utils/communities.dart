// SafePin が対応するコミュニティ(自治会/地域)の定義。
//
// Phase 1: 下目黒地区・目黒区・流山市の3コミュニティ。
// 案1に従い、管理パスワードは初期段階では全コミュニティ共通の
// 暫定ハッシュ(AppConstants.adminPassphraseHash と同一)を使用し、
// 後の Phase で管理画面から個別変更できるようにする。

import 'package:latlong2/latlong.dart';

import '../models/community.dart';
import 'constants.dart';
import 'service_area_data.dart';

/// 既定(URL/保存なしのフォールバック)のコミュニティID。
const String kDefaultCommunityId = 'shimomeguro';

/// 全コミュニティ定義(id -> Community)。
final Map<String, Community> kCommunities = {
  // ---- 下目黒地区(既存の丁目限定運用を独立コミュニティ化) ----
  'shimomeguro': Community(
    id: 'shimomeguro',
    name: '下目黒地区',
    center: const LatLng(35.628178, 139.702941),
    zoom: 15.0,
    area: Area.polygon(kServiceAreaPolygons),
    adminName: '下目黒地区 管理者',
    adminPassHash: AppConstants.adminPassphraseHash,
    note: 'このマップは下目黒4・5・6丁目を対象にした地域限定の実証運用です。',
  ),

  // ---- 東京都目黒区(市区町村全体) ----
  'meguro': Community(
    id: 'meguro',
    name: '東京都目黒区',
    center: const LatLng(35.6415, 139.6983),
    zoom: 13.0,
    area: const Area.municipality('13110'),
    adminName: '目黒区 管理者',
    adminPassHash: AppConstants.adminPassphraseHash,
    note: 'このマップは東京都目黒区を対象にした共助マップです。',
  ),

  // ---- 千葉県流山市(市区町村全体) ----
  'nagareyama': Community(
    id: 'nagareyama',
    name: '千葉県流山市',
    center: const LatLng(35.856, 139.902),
    zoom: 12.0,
    area: const Area.municipality('12220'),
    adminName: '流山市 管理者',
    adminPassHash: AppConstants.adminPassphraseHash,
    note: 'このマップは千葉県流山市を対象にした共助マップです。',
  ),
};

/// 表示順(選択UI用)。
const List<String> kCommunityOrder = [
  'shimomeguro',
  'meguro',
  'nagareyama',
];

/// id からコミュニティを取得(未知IDは既定を返す)。
Community communityById(String? id) {
  if (id != null && kCommunities.containsKey(id)) {
    return kCommunities[id]!;
  }
  return kCommunities[kDefaultCommunityId]!;
}

/// 有効なコミュニティIDか。
bool isValidCommunityId(String? id) =>
    id != null && kCommunities.containsKey(id);
