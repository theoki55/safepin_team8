import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/community.dart';
import '../models/resource.dart';
import '../models/resource_category.dart';
import '../utils/communities.dart';

/// CSV 1行の解析結果(プレビュー表示用)。
///
/// 行ごとに「そのまま登録できるか(ok)」「登録はできるが注意がある(warning)」
/// 「登録できない(error)」を保持し、プレビュー画面で色分け表示する。
class ResourceRow {
  /// CSV 上の行番号(ヘッダを1行目とした人間可読な番号)。
  final int lineNo;

  /// 解析できた資源(error の場合は null)。
  final Resource? resource;

  /// 致命的でない注意メッセージ(例: 区域外)。登録は可能。
  final List<String> warnings;

  /// 致命的エラー(登録不可)。
  final String? error;

  ResourceRow({
    required this.lineNo,
    this.resource,
    List<String>? warnings,
    this.error,
  }) : warnings = warnings ?? const [];

  bool get isError => error != null;
  bool get isWarning => error == null && warnings.isNotEmpty;
  bool get isOk => error == null && warnings.isEmpty;
}

/// 地域資源(RESOURCE)の CSV 一括インポート結果。
class ResourceImportResult {
  /// 全ての行の解析結果(順序保持)。
  final List<ResourceRow> rows;

  /// ヘッダ不正など、ファイル全体に関わる致命的エラー。空なら行単位で処理可。
  final List<String> fatalErrors;

  ResourceImportResult({
    required this.rows,
    List<String>? fatalErrors,
  }) : fatalErrors = fatalErrors ?? const [];

  bool get hasFatal => fatalErrors.isNotEmpty;

  /// 読み込もうとしたデータ行数(空行を除く)。
  int get total => rows.length;

  /// そのまま登録できる件数(ok)。
  int get okCount => rows.where((r) => r.isOk).length;

  /// 注意付きで登録できる件数(warning)。
  int get warningCount => rows.where((r) => r.isWarning).length;

  /// 登録できない件数(error)。
  int get errorCount => rows.where((r) => r.isError).length;

  /// 実際に登録可能な資源(ok + warning)。
  List<Resource> get importable =>
      rows.where((r) => !r.isError).map((r) => r.resource!).toList();
}

/// 地域資源の CSV パース + 検証サービス。
///
/// 想定カラム(ヘッダ必須・順不同):
///   category,name,lat,lng,address,note,managed_by,last_inspected,available
///
/// - `category` は enum キー(例: fireExtinguisher)または日本語ラベル(例: 街頭消火器)
///   のどちらでも受け付ける。
/// - `lat`/`lng` は必須。数値・範囲チェックを行う。
/// - サービス対象区域外の座標は「警告」とし、登録自体は許可する(方針: 区域外もブロックしない)。
/// - `available` は空なら true。"false"/"0"/"no"/"×"/"不可" 等で false。
class ResourceCsvService {
  final _uuid = const Uuid();

  /// 登録者の匿名UID/名前(監査用)。UI 側から渡す。
  ResourceImportResult parse(
    String content, {
    String registeredByUid = '',
    String registeredByName = '',
    Area? area,
    String communityId = '',
  }) {
    final rows = _splitCsvRows(content);
    if (rows.isEmpty) {
      return ResourceImportResult(rows: const [], fatalErrors: ['データがありません']);
    }

    // ヘッダ解析
    final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
    int col(List<String> names) {
      for (final n in names) {
        final idx = header.indexOf(n);
        if (idx >= 0) return idx;
      }
      return -1;
    }

    final iCategory = col(['category', 'カテゴリ', '種別']);
    final iName = col(['name', '名称', '名前']);
    final iLat = col(['lat', 'latitude', '緯度']);
    final iLng = col(['lng', 'lon', 'longitude', '経度']);
    final iAddress = col(['address', '住所']);
    final iNote = col(['note', 'メモ', '備考']);
    final iManagedBy = col(['managed_by', 'managedby', '管理', '管理団体']);
    final iLastInspected =
        col(['last_inspected', 'lastinspected', '点検日', '最終点検日']);
    final iAvailable = col(['available', '利用可否', '利用可能']);

    final missing = <String>[];
    if (iCategory < 0) missing.add('category');
    if (iName < 0) missing.add('name');
    if (iLat < 0) missing.add('lat');
    if (iLng < 0) missing.add('lng');
    if (missing.isNotEmpty) {
      return ResourceImportResult(
        rows: const [],
        fatalErrors: ['CSV ヘッダに必須列がありません: ${missing.join(", ")}'],
      );
    }

    final now = DateTime.now();
    final dataRows = rows.skip(1).toList();
    final result = <ResourceRow>[];

    for (var r = 0; r < dataRows.length; r++) {
      final row = dataRows[r];
      final lineNo = r + 2; // ヘッダ=1行目
      // 空行スキップ
      if (row.every((c) => c.trim().isEmpty)) continue;

      String cell(int idx) =>
          (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

      final errors = <String>[];
      final warnings = <String>[];

      // カテゴリ
      final categoryRaw = cell(iCategory);
      final category = ResourceCategory.resolve(categoryRaw);
      if (categoryRaw.isEmpty) {
        errors.add('カテゴリが空です');
      } else if (category == null) {
        errors.add('カテゴリ「$categoryRaw」は不明です');
      }

      // 名称
      final name = cell(iName);
      if (name.isEmpty) errors.add('名称が空です');

      // 緯度・経度
      final lat = _toDouble(cell(iLat));
      final lng = _toDouble(cell(iLng));
      if (lat == null) {
        errors.add('緯度が数値ではありません');
      } else if (lat < -90 || lat > 90) {
        errors.add('緯度が範囲外です(-90〜90)');
      }
      if (lng == null) {
        errors.add('経度が数値ではありません');
      } else if (lng < -180 || lng > 180) {
        errors.add('経度が範囲外です(-180〜180)');
      }

      // ここまででエラーがあれば行を確定
      if (errors.isNotEmpty || category == null || lat == null || lng == null) {
        result.add(ResourceRow(lineNo: lineNo, error: errors.join(' / ')));
        continue;
      }

      // 区域外チェック(警告のみ)。区域判定を持つコミュニティでのみ実施。
      final point = LatLng(lat, lng);
      if (area != null && area.hasBoundaryCheck && !area.contains(point)) {
        warnings.add('サービス対象区域外の座標です');
      }

      // 最終点検日(任意・パース失敗は警告)
      DateTime? lastInspected;
      final inspectedRaw = cell(iLastInspected);
      if (inspectedRaw.isNotEmpty) {
        lastInspected = _toDate(inspectedRaw);
        if (lastInspected == null) {
          warnings.add('点検日「$inspectedRaw」を日付として解釈できませんでした');
        }
      }

      // 利用可否(任意・空なら true)
      final available = _toBool(cell(iAvailable));

      final resource = Resource(
        id: _uuid.v4(),
        category: category,
        name: name,
        lat: lat,
        lng: lng,
        address: cell(iAddress),
        note: cell(iNote),
        managedBy: cell(iManagedBy),
        lastInspected: lastInspected,
        available: available,
        registeredByUid: registeredByUid,
        registeredByName: registeredByName,
        communityId: communityId.isNotEmpty ? communityId : kDefaultCommunityId,
        createdAt: now,
        updatedAt: now,
      );

      result.add(ResourceRow(
        lineNo: lineNo,
        resource: resource,
        warnings: warnings,
      ));
    }

    return ResourceImportResult(rows: result);
  }

  /// サンプルテンプレート(CSV)を返す。区域内(下目黒付近)の座標を使う。
  String sampleCsv() {
    return 'category,name,lat,lng,address,note,managed_by,last_inspected,available\n'
        'fireExtinguisher,下目黒4丁目 第1消火器,35.6282,139.7029,下目黒4-1付近,電柱脇に設置,下目黒町会,2026-01-15,true\n'
        'sandbag,5丁目 土のう置き場,35.6270,139.7040,下目黒5-3,浸水対策用,下目黒町会,,true\n'
        'aed,○○会館 AED,35.6290,139.7015,下目黒6-2 集会所内,平日9-17時に利用可,自治会,2026-02-01,true\n'
        'disasterWarehouse,防災倉庫(6丁目),35.6300,139.7005,下目黒6-5,発電機・工具あり,自治会防災部,,true\n'
        'well,共同井戸,35.6265,139.7050,下目黒4-8,生活用水のみ,,,\n'
        'waterSupply,応急給水拠点,35.6285,139.7060,下目黒5-1,発災時開設,区,,\n'
        'gatheringSpot,一時集合場所(公園),35.6278,139.7035,下目黒4-4 児童遊園,発災時に集合,下目黒町会,,\n';
  }

  /// テンプレート内の各列の説明(UI ヘルプ用)。
  static const Map<String, String> columnHelp = {
    'category': 'カテゴリ(fireExtinguisher/sandbag/aed/disasterWarehouse/well/'
        'waterSupply/gatheringSpot、または「街頭消火器」等の日本語)【必須】',
    'name': '表示名【必須】',
    'lat': '緯度(例: 35.6282)【必須】',
    'lng': '経度(例: 139.7029)【必須】',
    'address': '住所(任意)',
    'note': '注意・使い方メモ(任意)',
    'managed_by': '管理団体・自治会名(任意)',
    'last_inspected': '最終点検日(YYYY-MM-DD、任意)',
    'available': '利用可否(true/false、空欄は利用可)',
  };

  // ---------------- CSV 低レベルパーサ(pin_import_service と同一方式) ----------------

  /// 簡易 CSV パーサ(ダブルクォート/改行/カンマのエスケープに対応)。
  List<List<String>> _splitCsvRows(String content) {
    // BOM 除去
    var text = content;
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    bool inQuotes = false;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          row.add(field.toString());
          field = StringBuffer();
        } else if (ch == '\n' || ch == '\r') {
          if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
            i++;
          }
          row.add(field.toString());
          field = StringBuffer();
          rows.add(row);
          row = <String>[];
        } else {
          field.write(ch);
        }
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  static double? _toDouble(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static DateTime? _toDate(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    // 2026/01/15 のようなスラッシュ区切りも許容
    final normalized = s.replaceAll('/', '-');
    return DateTime.tryParse(normalized);
  }

  /// 利用可否。空なら true。false/0/no/×/不可/停止/撤去 等で false。
  static bool _toBool(String v) {
    final s = v.trim().toLowerCase();
    if (s.isEmpty) return true;
    const falsey = {
      'false',
      '0',
      'no',
      'n',
      'ng',
      '×',
      'x',
      '不可',
      '停止',
      '撤去',
      '点検中',
      '利用不可',
    };
    return !falsey.contains(s);
  }
}
