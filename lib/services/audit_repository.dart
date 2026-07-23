import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'admin_service.dart';

/// 監査ログ(操作ログ)の Firestore 保存を担うリポジトリ。
///
/// 端末ローカル(SharedPreferences)ではなく Firestore の
/// `audit_logs` コレクションに保存することで、
///  - ブラウザを閉じても記録が消えない
///  - 別端末・別ブラウザからも同じ記録を閲覧できる
///  - 複数の自治会役員の操作を一元的に追跡できる
/// を実現する(案A: Firestore 一本化)。
///
/// クエリは orderBy を使わずメモリでソートし、複合インデックス不要にする。
class AuditRepository {
  static const String _collection = 'audit_logs';

  /// 最大取得件数(表示件数)。古いものは取得対象から外す。
  static const int _fetchLimit = 500;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  /// 監査ログを1件追記する。
  ///
  /// 記録処理が本体操作(資源登録など)を妨げないよう、失敗しても例外を
  /// 投げずにログ出力のみ行う(fire-and-forget 的な扱い)。
  Future<void> append(AuditEntry entry) async {
    try {
      await _col.add({
        'action': entry.action,
        'detail': entry.detail,
        'adminName': entry.adminName,
        // タイムスタンプは検索・整合性のため Firestore の Timestamp で保持
        'at': Timestamp.fromDate(entry.at),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Audit log append failed (ignored): $e');
      }
    }
  }

  /// 監査ログを新しい順に取得する。
  Future<List<AuditEntry>> loadAll() async {
    try {
      final snap = await _col.limit(_fetchLimit).get();
      final entries = snap.docs
          .map((d) => _parse(d.data()))
          .whereType<AuditEntry>()
          .toList();
      // orderBy を使わずメモリでソート(複合インデックス不要)
      entries.sort((a, b) => b.at.compareTo(a.at));
      return entries;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Audit log load failed: $e');
      }
      return [];
    }
  }

  AuditEntry? _parse(Map<String, dynamic> data) {
    try {
      final rawAt = data['at'];
      final DateTime at;
      if (rawAt is Timestamp) {
        at = rawAt.toDate();
      } else if (rawAt is String) {
        at = DateTime.tryParse(rawAt) ?? DateTime.now();
      } else {
        at = DateTime.now();
      }
      return AuditEntry(
        action: (data['action'] as String?) ?? '',
        detail: (data['detail'] as String?) ?? '',
        adminName: (data['adminName'] as String?) ?? '',
        at: at,
      );
    } catch (_) {
      return null;
    }
  }
}
