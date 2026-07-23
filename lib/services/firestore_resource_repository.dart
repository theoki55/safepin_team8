import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/attachment.dart';
import '../models/resource.dart';
import 'attachment_service.dart';
import 'resource_repository.dart';

/// Firestore + Storage を使ったクラウド保存の実装(資源 = `resources` コレクション)。
///
/// - 資源本体: Firestore `resources` コレクション
/// - 添付本体: Storage `resources/{resourceId}/{attachmentId}_{name}`
/// - リアルタイム同期: `snapshots()` を [watch] で公開
/// - orderBy を使わずメモリでソートし、複合インデックス不要にする
/// - 一括登録は WriteBatch(500件上限)で分割コミット
class FirestoreResourceRepository extends ResourceRepository {
  static const String _collection = 'resources';
  static const int _batchLimit = 450; // Firestore の 500 に余裕を持たせる

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

  /// 添付を Storage にアップロードし、URL 付き添付リストを返す。
  ///
  /// アップロードに失敗した添付があった場合は [AttachmentUploadException] を
  /// 投げる。これにより「エラーなく完了したが保存されていない」という
  /// サイレント失敗を防ぎ、ユーザーに失敗を通知できる。
  Future<List<Attachment>> _uploadAttachments(
    String resourceId,
    List<Attachment> attachments,
  ) async {
    final result = <Attachment>[];
    Object? firstError;
    var failed = 0;
    for (final a in attachments) {
      // 既に URL 済み(アップロード済み)ならそのまま
      if (a.url != null && a.dataUrl == null) {
        result.add(a);
        continue;
      }
      final bytes = AttachmentBytes.decode(a);
      if (bytes == null) {
        failed++;
        firstError ??= '添付「${a.name}」のデータを読み込めませんでした';
        continue;
      }
      final path = 'resources/$resourceId/${a.id}_${_sanitize(a.name)}';
      try {
        final ref = _storage.ref(path);
        final metadata = SettableMetadata(contentType: a.mimeType);
        await ref.putData(Uint8List.fromList(bytes), metadata);
        final url = await ref.getDownloadURL();
        result.add(a.copyWith(url: url, storagePath: path));
      } catch (e) {
        failed++;
        firstError ??= e;
        if (kDebugMode) {
          debugPrint('Resource attachment upload failed: $e');
        }
      }
    }
    if (failed > 0) {
      throw AttachmentUploadException(
        '添付ファイルのアップロードに失敗しました（$failed件）: $firstError',
      );
    }
    return result;
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_');

  @override
  Future<void> add(Resource resource) async {
    final uploaded = await _uploadAttachments(resource.id, resource.attachments);
    final toSave = resource.copyWith(attachments: uploaded);
    await _col.doc(resource.id).set(toSave.toFirestoreMap());
  }

  @override
  Future<void> update(Resource resource) async {
    final uploaded = await _uploadAttachments(resource.id, resource.attachments);
    final toSave = resource.copyWith(attachments: uploaded);
    await _col.doc(resource.id).set(toSave.toFirestoreMap());
  }

  @override
  Future<void> delete(String id) async {
    // 添付ファイルも Storage から削除する。
    try {
      final doc = await _col.doc(id).get();
      final data = doc.data();
      if (data != null) {
        final atts = (data['attachments'] as List?) ?? const [];
        for (final raw in atts) {
          if (raw is Map) {
            final sp = raw['storagePath'] as String?;
            if (sp != null && sp.isNotEmpty) {
              try {
                await _storage.ref(sp).delete();
              } catch (_) {
                // 既に無い等は無視
              }
            }
          }
        }
      }
    } catch (_) {
      // 添付削除失敗は本体削除を妨げない
    }
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

/// 添付ファイルの Storage アップロード失敗を表す例外。
class AttachmentUploadException implements Exception {
  final String message;
  const AttachmentUploadException(this.message);

  @override
  String toString() => message;
}
