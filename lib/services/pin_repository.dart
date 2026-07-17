import '../models/attachment.dart';
import '../models/pin.dart';

/// ピンの永続化を抽象化するインターフェース。
///
/// ローカル保存は [HivePinRepository]、クラウド保存は [FirestorePinRepository]。
/// [main.dart] の生成箇所を差し替えるだけで実装を切替できる。
abstract class PinRepository {
  Future<void> init();

  /// すべてのピンを取得(新しい順)
  Future<List<Pin>> getAll();

  /// リアルタイム更新のストリーム。対応しない実装では null を返す。
  Stream<List<Pin>>? watch() => null;

  /// 添付をアップロードして URL 付き添付を返す(クラウド実装用)。
  /// ローカル実装ではそのまま返す。
  Future<List<Attachment>> uploadAttachments(
    String pinId,
    List<Attachment> attachments,
  ) async =>
      attachments;

  Future<void> add(Pin pin);

  Future<void> update(Pin pin);

  Future<void> delete(String id);
}
