import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/enums.dart';
import '../models/pin.dart';

/// 在宅避難者のプライバシー保護のための「位置ぼかし」ユーティリティ。
///
/// NEED / OFFER のピンは自宅など個人の生活拠点と結びつきやすく、
/// 正確な位置を公開すると防犯上のリスク(空き巣など)につながる。
/// そこで、これらのピンは表示・共有時に約150mのグリッド(メッシュ)へ
/// 丸め、そのマスの中心に配置する。INFO(給水所・通行止め等の地域情報)は
/// 地点そのものが有用なため、正確な位置のまま表示する。
///
/// 元データ(Firestore 上の lat/lng)は変更しない。あくまで「表示時」に
/// 丸めるだけなので、既存投稿もデータ移行なしでぼかし表示に切り替わる。
class LocationBlur {
  /// グリッドの一辺の長さ(メートル)。地域感覚に合わせて 150m を採用。
  static const double gridMeters = 150.0;

  /// ぼかし円の半径(メートル)。グリッドの半分(=約75m)。
  /// 「正確な位置ではなく、このあたり」であることを利用者に示すために描画する。
  static const double circleRadiusMeters = gridMeters / 2;

  /// 緯度1度あたりのおおよその距離(メートル)。
  static const double _metersPerLatDegree = 111320.0;

  /// この種別の位置をぼかす対象かどうか。
  /// - NEED / OFFER: ぼかす(自宅と結びつきやすい)
  /// - INFO:         ぼかさない(地点情報として正確な方が有用)
  static bool shouldBlur(PinType type) {
    switch (type) {
      case PinType.need:
      case PinType.offer:
        return true;
      case PinType.info:
        return false;
    }
  }

  /// 緯度経度を約150mグリッドの「マスの中心」に丸める。
  ///
  /// 経度方向のメッシュ幅は緯度によって変わる(高緯度ほど狭い)ため、
  /// cos(緯度) で補正する。
  static LatLng snapToGrid(double lat, double lng) {
    // 緯度方向のグリッド幅(度)
    final latStep = gridMeters / _metersPerLatDegree;

    // 経度方向のグリッド幅(度)。緯度に応じて補正。
    final metersPerLngDegree =
        _metersPerLatDegree * math.cos(lat * math.pi / 180.0);
    // 極付近で 0 除算にならないようガード
    final safeMetersPerLng =
        metersPerLngDegree.abs() < 1.0 ? 1.0 : metersPerLngDegree;
    final lngStep = gridMeters / safeMetersPerLng;

    // マスの下端インデックス → マスの中心に丸める(下端 + 半マス)
    final latIndex = (lat / latStep).floor();
    final lngIndex = (lng / lngStep).floor();

    final snappedLat = (latIndex + 0.5) * latStep;
    final snappedLng = (lngIndex + 0.5) * lngStep;

    return LatLng(snappedLat, snappedLng);
  }

  /// ピンの「表示用座標」を返す。
  /// ぼかし対象(NEED/OFFER)はグリッド中心に丸め、INFO は正確な位置を返す。
  static LatLng displayLatLng(Pin pin) {
    if (shouldBlur(pin.type)) {
      return snapToGrid(pin.lat, pin.lng);
    }
    return LatLng(pin.lat, pin.lng);
  }

  /// このピンが表示時にぼかされているか(円の描画・注意書き表示の判定に使う)。
  static bool isBlurred(Pin pin) => shouldBlur(pin.type);
}
