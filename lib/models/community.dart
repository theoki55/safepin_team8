// SafePin コミュニティ(自治会/地域)モデル。
//
// 複数コミュニティ対応(Phase 1)の中核。1つのコミュニティは
// 名称・管理者・管理パスワード・地図中心/ズーム・対象区域(Area)を
// 個別に持つ。ピン/資源/監査ログは communityId で分離される。

import 'package:latlong2/latlong.dart';

import '../utils/service_area_data.dart';

/// 対象区域の指定方式。
enum AreaType {
  /// 丁目単位のポリゴン(点in多角形判定あり)。例: 下目黒4・5・6丁目。
  polygon,

  /// 市区町村全体(区域外警告を出さない)。例: 目黒区・流山市。
  municipality,

  /// 中心+半径(距離判定)。
  circle,

  /// 制限なし(判定なし)。
  none,
}

AreaType areaTypeFromString(String? s) {
  switch (s) {
    case 'polygon':
      return AreaType.polygon;
    case 'municipality':
      return AreaType.municipality;
    case 'circle':
      return AreaType.circle;
    case 'none':
      return AreaType.none;
    default:
      return AreaType.none;
  }
}

String areaTypeToString(AreaType t) {
  switch (t) {
    case AreaType.polygon:
      return 'polygon';
    case AreaType.municipality:
      return 'municipality';
    case AreaType.circle:
      return 'circle';
    case AreaType.none:
      return 'none';
  }
}

/// コミュニティの対象区域定義。
///
/// - polygon: [polygons] を使う(丁目ポリゴン群)。in/out 判定あり。
/// - municipality: [municipalityCode] を保持するのみ。判定なし(警告を出さない)。
/// - circle: [center] + [radiusMeters] で距離判定。
/// - none: 判定なし。
class Area {
  final AreaType type;

  /// polygon 用: 丁目ポリゴン群(名前+頂点列)。
  final List<ServiceAreaPolygon> polygons;

  /// municipality 用: 全国地方公共団体コード(例: "13110")。
  final String? municipalityCode;

  /// circle 用: 中心座標。
  final LatLng? center;

  /// circle 用: 半径(メートル)。
  final double? radiusMeters;

  const Area({
    required this.type,
    this.polygons = const [],
    this.municipalityCode,
    this.center,
    this.radiusMeters,
  });

  /// 丁目ポリゴンによる区域。
  const Area.polygon(List<ServiceAreaPolygon> polygons)
      : this(type: AreaType.polygon, polygons: polygons);

  /// 市区町村全体による区域。
  const Area.municipality(String code)
      : this(type: AreaType.municipality, municipalityCode: code);

  /// 円(中心+半径)による区域。
  const Area.circle(LatLng center, double radiusMeters)
      : this(type: AreaType.circle, center: center, radiusMeters: radiusMeters);

  /// 制限なし。
  const Area.none() : this(type: AreaType.none);

  /// この区域が in/out 判定を持つか(UIの区域外警告を出すか)。
  bool get hasBoundaryCheck => type == AreaType.polygon || type == AreaType.circle;

  /// 指定座標が区域内か。判定を持たないタイプ(municipality/none)は常に true。
  bool contains(LatLng point) {
    switch (type) {
      case AreaType.polygon:
        for (final p in polygons) {
          if (_pointInPolygon(point, p.points)) return true;
        }
        return false;
      case AreaType.circle:
        if (center == null || radiusMeters == null) return true;
        final d = const Distance().as(LengthUnit.Meter, center!, point);
        return d <= radiusMeters!;
      case AreaType.municipality:
      case AreaType.none:
        return true;
    }
  }

  /// 指定座標が含まれる丁目名(polygonのみ)。該当なし/対象外タイプは null。
  String? areaNameOf(LatLng point) {
    if (type != AreaType.polygon) return null;
    for (final p in polygons) {
      if (_pointInPolygon(point, p.points)) return p.name;
    }
    return null;
  }

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

/// コミュニティ(自治会/地域)。
class Community {
  /// URLパラメータ・データ分離に使う識別子(例: "shimomeguro")。
  final String id;

  /// 表示名(例: "下目黒地区")。
  final String name;

  /// 地図初期中心。
  final LatLng center;

  /// 地図初期ズーム。
  final double zoom;

  /// 対象区域定義。
  final Area area;

  /// 管理者(自治会役員)の名称。
  final String adminName;

  /// 管理パスワードの SHA-256 ハッシュ。
  /// (案1: 初期は全コミュニティ共通の暫定ハッシュ。後で個別変更可能にする。)
  final String adminPassHash;

  /// UI 表示用の区域説明テキスト。
  final String note;

  const Community({
    required this.id,
    required this.name,
    required this.center,
    required this.zoom,
    required this.area,
    required this.adminName,
    required this.adminPassHash,
    required this.note,
  });

  Community copyWith({
    String? name,
    LatLng? center,
    double? zoom,
    Area? area,
    String? adminName,
    String? adminPassHash,
    String? note,
  }) {
    return Community(
      id: id,
      name: name ?? this.name,
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      area: area ?? this.area,
      adminName: adminName ?? this.adminName,
      adminPassHash: adminPassHash ?? this.adminPassHash,
      note: note ?? this.note,
    );
  }
}
