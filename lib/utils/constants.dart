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
}
