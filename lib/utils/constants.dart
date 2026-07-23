import 'package:latlong2/latlong.dart';

/// アプリ全体で使う定数。
class AppConstants {
  /// 初期表示の地図中心(サービス対象区域=下目黒4・5・6丁目の中心付近)。
  static const LatLng defaultCenter = LatLng(35.628178, 139.702941);
  static const double defaultZoom = 15.0;

  /// OpenStreetMap タイル(APIキー不要)
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmUserAgent = 'com.crisiscompass.map';

  static const String appName = 'SafePin';
  static const String appTagline = '在宅避難の見えない孤立を、地図でつなぐ';

  // ---- ステップB: コミュニティ運用の定数 ----

  /// 管理者(自治会役員)モードを有効にする合言葉の SHA-256 ハッシュ。
  ///
  /// 平文をソースに埋め込まないことで、ビルド成果物から合言葉が
  /// そのまま漏れることを防ぐ。照合時は入力を同じくハッシュ化して比較する。
  /// (元の合言葉はパイロット運用者にのみ口頭/紙で共有する。)
  static const String adminPassphraseHash =
      'fd25baf95c40a8e646d1b1e6471c1b7b26e57853d4e79cb75b2511d7cac7b585';

  /// 管理者セッションの有効時間(分)。
  /// この時間を過ぎると管理者モードは自動的に解除され、再度合言葉が必要になる。
  /// 共有端末での「管理者モードの付けっぱなし」による誤操作/権限漏れを防ぐ。
  static const int adminSessionMinutes = 60;

  /// 監査ログとして保持する最大件数(端末ローカル / shared_preferences)。
  static const int adminAuditMaxEntries = 200;

  /// この件数以上の通報で投稿を自動的に非表示にする。
  static const int reportHideThreshold = 3;

  /// この人数以上が「現地確認済」を押したら、未確認の投稿を
  /// 自動的に「現地確認済」ステータスへ引き上げる。
  static const int confirmAutoThreshold = 2;

  /// 「古い情報」が「役に立った」を上回り、かつこの件数を超えたら
  /// 「古い可能性」の注意表示を出す(自動非表示はしない)。
  static const int outdatedWarnThreshold = 3;

  // ---- 機能⑥: サービス対象区域(丁目境界) ----

  /// 対象区域の説明テキスト(UI 表示用)。
  /// 実際の丁目名は ServiceArea.areaLabel から動的に取得する。
  static const String serviceAreaNote =
      'このアプリは下目黒4・5・6丁目を対象にした地域限定の実証運用です。';

  /// 区域境界ポリゴンの線・塗りの色(緑系)。
  static const int serviceAreaColorValue = 0xFF2E7D32;
}
