import 'package:latlong2/latlong.dart';

/// アプリ全体で使う定数。
class AppConstants {
  /// 初期表示の地図中心(東京駅周辺)。実運用では対象地域に合わせて変更する。
  static const LatLng defaultCenter = LatLng(35.681236, 139.767125);
  static const double defaultZoom = 15.0;

  /// OpenStreetMap タイル(APIキー不要)
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmUserAgent = 'com.crisiscompass.map';

  static const String appName = 'SafePin';
  static const String appTagline = '在宅避難の見えない孤立を、地図でつなぐ';

  // ---- ステップB: コミュニティ運用の定数 ----

  /// 管理者(自治会役員)モードを有効にする合言葉。
  /// パイロットでは運用者にのみ口頭/紙で共有する。
  static const String adminPassphrase = 'safepin-team8-2026';

  /// この件数以上の通報で投稿を自動的に非表示にする。
  static const int reportHideThreshold = 3;

  /// この人数以上が「現地確認済」を押したら、未確認の投稿を
  /// 自動的に「現地確認済」ステータスへ引き上げる。
  static const int confirmAutoThreshold = 2;

  /// 「古い情報」が「役に立った」を上回り、かつこの件数を超えたら
  /// 「古い可能性」の注意表示を出す(自動非表示はしない)。
  static const int outdatedWarnThreshold = 3;
}
