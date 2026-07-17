import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/pin.dart';

/// インポート結果。
class ImportResult {
  final List<Pin> pins;
  final int total; // 読み込もうとした行/レコード数
  final int skipped; // 不正でスキップした数
  final List<String> errors;

  ImportResult({
    required this.pins,
    required this.total,
    required this.skipped,
    required this.errors,
  });

  bool get hasPins => pins.isNotEmpty;
}

/// 投稿(ピン)の一括インポート/エクスポートを担うサービス。
///
/// 対応フォーマット:
/// - JSON: [{"type":"need","title":...,"lat":...,"lng":...}, ...]
/// - CSV : ヘッダ行 + データ行 (type,title,comment,lat,lng,priority,status,mode,authorName)
class PinImportService {
  final _uuid = const Uuid();

  /// ファイル内容(文字列)を解析してピン一覧を返す。
  /// 拡張子/内容から JSON / CSV を自動判定する。
  ImportResult parse(String content, {String? fileName}) {
    final trimmed = content.trim();
    final isJson = (fileName?.toLowerCase().endsWith('.json') ?? false) ||
        trimmed.startsWith('[') ||
        trimmed.startsWith('{');
    if (isJson) return _parseJson(trimmed);
    return _parseCsv(trimmed);
  }

  // ---------------- JSON ----------------
  ImportResult _parseJson(String content) {
    final errors = <String>[];
    final pins = <Pin>[];
    int total = 0;
    int skipped = 0;
    try {
      final decoded = jsonDecode(content);
      final List list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map && decoded['pins'] is List) {
        // {"pins": [...]} 形式にも対応
        list = decoded['pins'] as List;
      } else {
        return ImportResult(
          pins: const [],
          total: 0,
          skipped: 0,
          errors: ['JSON のトップレベルは配列、または {"pins":[...]} 形式にしてください'],
        );
      }
      total = list.length;
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        if (item is! Map) {
          skipped++;
          errors.add('${i + 1}件目: オブジェクトではありません');
          continue;
        }
        final pin = _fromMap(item.cast<String, dynamic>());
        if (pin == null) {
          skipped++;
          errors.add('${i + 1}件目: 緯度/経度が不正です');
        } else {
          pins.add(pin);
        }
      }
    } catch (e) {
      return ImportResult(
        pins: const [],
        total: 0,
        skipped: 0,
        errors: ['JSON の解析に失敗しました: $e'],
      );
    }
    return ImportResult(
        pins: pins, total: total, skipped: skipped, errors: errors);
  }

  Pin? _fromMap(Map<String, dynamic> m) {
    final lat = _toDouble(m['lat']);
    final lng = _toDouble(m['lng']);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

    final type = PinType.fromName((m['type'] ?? 'info').toString());
    var status = PinStatus.fromName((m['status'] ?? 'unconfirmed').toString());
    // 種別が対応しないステータスは、その種別の初期値に丸める
    if (!type.supportsStatus(status)) {
      status = type.availableStatuses.first;
    }
    final now = DateTime.now();
    final createdAt = _toDate(m['createdAt']) ?? now;
    return Pin(
      id: (m['id']?.toString().isNotEmpty ?? false)
          ? m['id'].toString()
          : _uuid.v4(),
      type: type,
      status: status,
      priority: PinPriority.fromName((m['priority'] ?? 'medium').toString()),
      title: (m['title'] ?? '').toString(),
      comment: (m['comment'] ?? '').toString(),
      lat: lat,
      lng: lng,
      authorName: (m['authorName'] ?? m['author'] ?? '匿名').toString(),
      mode: AppMode.fromName((m['mode'] ?? 'disaster').toString()),
      attachments: const [], // 一括アップロードでは添付は対象外
      createdAt: createdAt,
      updatedAt: _toDate(m['updatedAt']) ?? createdAt,
    );
  }

  // ---------------- CSV ----------------
  ImportResult _parseCsv(String content) {
    final errors = <String>[];
    final pins = <Pin>[];
    final rows = _splitCsvRows(content);
    if (rows.isEmpty) {
      return ImportResult(
          pins: const [], total: 0, skipped: 0, errors: ['データがありません']);
    }
    // ヘッダ解析
    final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
    int col(String name) => header.indexOf(name);
    final iType = col('type');
    final iTitle = col('title');
    final iComment = col('comment');
    final iLat = col('lat');
    final iLng = col('lng');
    final iPriority = col('priority');
    final iStatus = col('status');
    final iMode = col('mode');
    final iAuthor =
        col('authorname') >= 0 ? col('authorname') : col('author');

    if (iLat < 0 || iLng < 0) {
      return ImportResult(
        pins: const [],
        total: 0,
        skipped: 0,
        errors: ['CSV ヘッダに lat / lng 列が必要です'],
      );
    }

    final dataRows = rows.skip(1).toList();
    int skipped = 0;
    for (var r = 0; r < dataRows.length; r++) {
      final row = dataRows[r];
      String cell(int idx) =>
          (idx >= 0 && idx < row.length) ? row[idx].trim() : '';
      // 空行スキップ
      if (row.every((c) => c.trim().isEmpty)) continue;

      final map = <String, dynamic>{
        'type': cell(iType),
        'title': cell(iTitle),
        'comment': cell(iComment),
        'lat': cell(iLat),
        'lng': cell(iLng),
        'priority': cell(iPriority),
        'status': cell(iStatus),
        'mode': cell(iMode),
        'authorName': cell(iAuthor),
      };
      final pin = _fromMap(map);
      if (pin == null) {
        skipped++;
        errors.add('${r + 2}行目: 緯度/経度が不正です');
      } else {
        pins.add(pin);
      }
    }
    return ImportResult(
      pins: pins,
      total: dataRows.where((row) => row.any((c) => c.trim().isNotEmpty)).length,
      skipped: skipped,
      errors: errors,
    );
  }

  /// 簡易 CSV パーサ(ダブルクォート/改行/カンマのエスケープに対応)。
  List<List<String>> _splitCsvRows(String content) {
    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    bool inQuotes = false;

    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
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
          // 行末(CRLF の \r は次で \n も来るが空フィールドとしては扱わない)
          if (ch == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
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
    // 末尾フィールド/行
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  // ---------------- Export ----------------
  /// ピン一覧を JSON 文字列に変換(エクスポート用)。
  String toJson(List<Pin> pins) {
    final list = pins
        .map((p) => {
              'id': p.id,
              'type': p.type.name,
              'status': p.status.name,
              'priority': p.priority.name,
              'title': p.title,
              'comment': p.comment,
              'lat': p.lat,
              'lng': p.lng,
              'authorName': p.authorName,
              'mode': p.mode.name,
              'createdAt': p.createdAt.toIso8601String(),
              'updatedAt': p.updatedAt.toIso8601String(),
            })
        .toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// ピン一覧を CSV 文字列に変換(エクスポート用)。
  String toCsv(List<Pin> pins) {
    final sb = StringBuffer();
    sb.writeln(
        'type,title,comment,lat,lng,priority,status,mode,authorName,createdAt');
    for (final p in pins) {
      sb.writeln([
        p.type.name,
        p.title,
        p.comment,
        p.lat,
        p.lng,
        p.priority.name,
        p.status.name,
        p.mode.name,
        p.authorName,
        p.createdAt.toIso8601String(),
      ].map(_csvEscape).join(','));
    }
    return sb.toString();
  }

  String _csvEscape(Object? v) {
    final s = (v ?? '').toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// サンプルテンプレート(CSV)を返す。
  String sampleCsv() {
    return 'type,title,comment,lat,lng,priority,status,mode,authorName\n'
        'need,水が不足しています,飲料水が必要です,35.681,139.767,high,unconfirmed,disaster,匿名\n'
        'offer,毛布を提供できます,10枚あります,35.690,139.700,medium,confirmed,disaster,山田\n'
        'info,給水所開設,10時から16時,35.685,139.710,low,unconfirmed,disaster,自治会\n';
  }

  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  static DateTime? _toDate(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}
