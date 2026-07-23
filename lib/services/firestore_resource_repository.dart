import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/resource.dart';
import 'resource_repository.dart';

/// Firestore を使ったクラウド保存の実装(資源 = `resources` コレクション)。
///
/// - リアルタイム同期: `snapshots()` を [watch] で公開
/// - orderBy を使わずメモリでソートし、複合インデックス不要にする
/// - 一括登録は WriteBatch(500件上限)で分割コミット
class FirestoreResourceRepository extends ResourceRepository {
  static const String _collection = 'resources';
  static const int _batchLimit = 450; // Firestore の 500 に余裕を持たせる

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  @override
  Future<void> init() async {
    // Firestore の settings は pin リポジトリ側で設定済み(persistenceEnabled=false)。
  }

  @override
  Future<List<Resource>> getAll() async {
    final snap = await _col.get();
    final list = snap.docs
        .map((d) => _safeParse(d.data()))
        .whereType<Resource>()
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Stream<List<Resource>> watch() {
    return _col.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => _safeParse(d.data()))
          .whereType<Resource>()
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Resource? _safeParse(Map<String, dynamic> data) {
    try {
      return Resource.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> add(Resource resource) async {
    await _col.doc(resource.id).set(resource.toFirestoreMap());
  }

  @override
  Future<void> update(Resource resource) async {
    await _col.doc(resource.id).set(resource.toFirestoreMap());
  }

  @override
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  @override
  Future<int> addMany(List<Resource> resources) async {
    if (resources.isEmpty) return 0;
    var saved = 0;
    for (var i = 0; i < resources.length; i += _batchLimit) {
      final chunk = resources.sublist(
        i,
        (i + _batchLimit).clamp(0, resources.length),
      );
      final batch = _db.batch();
      for (final r in chunk) {
        batch.set(_col.doc(r.id), r.toFirestoreMap());
      }
      try {
        await batch.commit();
        saved += chunk.length;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('resource batch commit failed: $e');
        }
      }
    }
    return saved;
  }
}
