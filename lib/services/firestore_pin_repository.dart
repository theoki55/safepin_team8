import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/attachment.dart';
import '../models/pin.dart';
import 'attachment_service.dart';
import 'pin_repository.dart';

/// Firestore + Storage を使ったクラウド保存の実装。
///
/// - ピン本体: Firestore `pins` コレクション
/// - 添付本体: Storage `pins/{pinId}/{attachmentId}_{name}`
/// - リアルタイム同期: `snapshots()` を [watch] で公開
class FirestorePinRepository extends PinRepository {
  static const String _collection = 'pins';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  @override
  Future<void> init() async {
    // シークレット/プライベートモードでは IndexedDB が無効化される
    // ことがあり、Firestore のオフライン永続化(既定で有効)が失敗して
    // 画面が真っ白になる。SafePin はリアルタイム同期主体のため、
    // 永続化を無効化(メモリキャッシュ)して全ブラウザで安定動作させる。
    try {
      _db.settings = const Settings(persistenceEnabled: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore settings error (ignored): $e');
      }
    }
  }

  @override
  Future<List<Pin>> getAll() async {
    final snap = await _col.get();
    final pins = snap.docs
        .map((d) => _safeParse(d.data()))
        .whereType<Pin>()
        .toList();
    pins.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pins;
  }

  /// リアルタイム同期ストリーム。
  /// orderBy を使わずメモリでソートし、複合インデックス不要にする。
  @override
  Stream<List<Pin>> watch() {
    return _col.snapshots().map((snap) {
      final pins = snap.docs
          .map((d) => _safeParse(d.data()))
          .whereType<Pin>()
          .toList();
      pins.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return pins;
    });
  }

  Pin? _safeParse(Map<String, dynamic> data) {
    try {
      return Pin.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  /// 添付を Storage にアップロードし、URL 付き添付リストを返す。
  @override
  Future<List<Attachment>> uploadAttachments(
    String pinId,
    List<Attachment> attachments,
  ) async {
    final result = <Attachment>[];
    for (final a in attachments) {
      // 既に URL 済み(アップロード済み)ならそのまま
      if (a.url != null && a.dataUrl == null) {
        result.add(a);
        continue;
      }
      final bytes = AttachmentBytes.decode(a);
      if (bytes == null) {
        // 本体が取れない場合はスキップ
        continue;
      }
      final path = 'pins/$pinId/${a.id}_${_sanitize(a.name)}';
      try {
        final ref = _storage.ref(path);
        final metadata = SettableMetadata(contentType: a.mimeType);
        await ref.putData(Uint8List.fromList(bytes), metadata);
        final url = await ref.getDownloadURL();
        result.add(a.copyWith(url: url, storagePath: path));
      } catch (e) {
        // Storage 未有効化 / 権限エラー等の場合でも投稿自体は成立させる。
        // 添付は保存できなかったものとしてスキップする。
        if (kDebugMode) {
          debugPrint('Attachment upload failed (skipped): $e');
        }
        continue;
      }
    }
    return result;
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_');

  @override
  Future<void> add(Pin pin) async {
    // 添付を Storage にアップロードしてから Firestore に書き込む
    final uploaded = await uploadAttachments(pin.id, pin.attachments);
    final toSave = pin.copyWith(attachments: uploaded);
    await _col.doc(pin.id).set(toSave.toFirestoreMap());
  }

  @override
  Future<void> update(Pin pin) async {
    final uploaded = await uploadAttachments(pin.id, pin.attachments);
    final toSave = pin.copyWith(attachments: uploaded);
    await _col.doc(pin.id).set(toSave.toFirestoreMap());
  }

  @override
  Future<void> delete(String id) async {
    // 添付ファイルも Storage から削除
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
}
