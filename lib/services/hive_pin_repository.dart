import 'package:hive_flutter/hive_flutter.dart';

import '../models/pin.dart';
import 'pin_repository.dart';

/// Hive を使ったローカル(端末内)ピン保存の実装。
///
/// ピンは `Map<String, dynamic>` として box に格納する。
/// これにより TypeAdapter のコード生成なしで動作し、
/// 将来 Firestore へ移行する際もデータ形状を再利用できる。
class HivePinRepository extends PinRepository {
  static const String _boxName = 'pins_box';
  Box? _box;

  @override
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Box get _requireBox {
    final b = _box;
    if (b == null) {
      throw StateError('HivePinRepository is not initialized. Call init() first.');
    }
    return b;
  }

  @override
  Future<List<Pin>> getAll() async {
    final box = _requireBox;
    final pins = <Pin>[];
    for (final value in box.values) {
      if (value is Map) {
        try {
          pins.add(Pin.fromMap(value));
        } catch (_) {
          // 破損データはスキップ
        }
      }
    }
    pins.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pins;
  }

  @override
  Future<void> add(Pin pin) async {
    await _requireBox.put(pin.id, pin.toMap());
  }

  @override
  Future<void> update(Pin pin) async {
    await _requireBox.put(pin.id, pin.toMap());
  }

  @override
  Future<void> delete(String id) async {
    await _requireBox.delete(id);
  }
}
