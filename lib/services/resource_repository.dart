import '../models/resource.dart';

/// 地域資源(RESOURCE)の永続化を抽象化するインターフェース。
///
/// ピンの [PinRepository] と同じ設計で、ローカル(Hive)/クラウド(Firestore)を
/// 差し替えできるようにする。添付(写真・ファイル)は [add]/[update] 実装内で
/// Storage へアップロードしてから本体を保存する。
abstract class ResourceRepository {
  Future<void> init();

  /// すべての資源を取得(新しい順)。
  Future<List<Resource>> getAll();

  /// リアルタイム更新のストリーム。対応しない実装では null を返す。
  Stream<List<Resource>>? watch() => null;

  Future<void> add(Resource resource);

  Future<void> update(Resource resource);

  Future<void> delete(String id);

  /// 複数件をまとめて書き込む(CSV一括アップロード用)。
  /// 実装は成功件数を返す。
  Future<int> addMany(List<Resource> resources);
}
