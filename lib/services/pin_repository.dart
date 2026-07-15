import '../models/pin.dart';

/// ピンの永続化を抽象化するインターフェース。
///
/// 現在は [HivePinRepository](ローカル保存)を利用。
/// Firebase 移行時は Firestore/Storage を使う実装を作り、
/// [main.dart] の Provider 登録を差し替えるだけで移行できる。
abstract class PinRepository {
  Future<void> init();

  /// すべてのピンを取得(新しい順)
  Future<List<Pin>> getAll();

  Future<void> add(Pin pin);

  Future<void> update(Pin pin);

  Future<void> delete(String id);
}
