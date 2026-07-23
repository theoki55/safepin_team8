// SafePin サービス対象区域の判定ユーティリティ。
//
// 対象区域（下目黒4・5・6丁目）の境界ポリゴンに対して、
// 任意の緯度経度が区域内かどうかを判定する。
//
// 判定はレイキャスティング法（ray-casting / even-odd rule）を用いる。
// 区域外でも投稿はブロックしない（警告のみ）方針のため、
// この判定結果は UI の注意喚起にのみ利用する。

import 'package:latlong2/latlong.dart';

import 'service_area_data.dart';

class ServiceArea {
  const ServiceArea._();

  /// 対象区域の丁目名一覧（例: ["下目黒4丁目", ...]）。
  static List<String> get areaNames =>
      kServiceAreaPolygons.map((e) => e.name).toList();

  /// 対象区域の表示用ラベル（例: "下目黒4・5・6丁目"）。
  static String get areaLabel {
    // "下目黒4丁目" などから数字部分だけを抜き出して連結する。
    final chomes = <String>[];
    String prefix = '';
    for (final p in kServiceAreaPolygons) {
      final m = RegExp(r'^(.*?)(\d+)丁目$').firstMatch(p.name);
      if (m != null) {
        prefix = m.group(1) ?? '';
        chomes.add(m.group(2) ?? '');
      }
    }
    if (chomes.isEmpty) return areaNames.join('・');
    return '$prefix${chomes.join('・')}丁目';
  }

  /// 指定座標が対象区域（いずれかの丁目ポリゴン）内にあれば true。
  static bool contains(LatLng point) {
    for (final area in kServiceAreaPolygons) {
      if (_pointInPolygon(point, area.points)) return true;
    }
    return false;
  }

  /// 指定座標が含まれる丁目名を返す。区域外なら null。
  static String? areaNameOf(LatLng point) {
    for (final area in kServiceAreaPolygons) {
      if (_pointInPolygon(point, area.points)) return area.name;
    }
    return null;
  }

  /// レイキャスティング法による内外判定。
  ///
  /// polygon は外周の頂点列（[lat, lng]）。始点=終点でなくても動作する。
  static bool _pointInPolygon(LatLng p, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    final double x = p.longitude;
    final double y = p.latitude;
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;

      final double denom = (yj - yi) == 0 ? 1e-12 : (yj - yi);
      final bool intersect =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / denom + xi);
      if (intersect) inside = !inside;
      j = i;
    }
    return inside;
  }
}
