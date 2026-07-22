import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 一般住民の投稿向けの「簡易認証」を担うサービス。
///
/// 方式: 端末ごとの匿名ID(UUID)をローカル(shared_preferences)に保存する
/// 自前の軽量な仕組み。
///
/// - ユーザー入力ゼロ。初回起動時に UUID を1つ生成して端末に保存する。
/// - 個人情報は一切収集しない(自治会側の管理責任を増やさない)。
/// - 「同じ端末 = 同じ deviceId」なので、自分の投稿だけを編集/削除できる、
///   といった最低限の投稿統制が可能になる。
///
/// 注意: これはサーバー側で本人性を保証するものではなく、
/// 端末のIDを消せば別人として振る舞える。あくまで実証(ステップA)段階の
/// 「自分の投稿を自分で管理する」「軽い荒らし抑止」を目的とした簡易認証。
/// 厳格な本人確認が必要になれば、後段(Phase 1.5)でメール/OTP認証等へ差し替える。
class AuthService {
  static const _kDeviceId = 'safepin_device_id';

  String? _uid;

  /// 直近のエラー(診断用)。成功時は null。
  String? lastError;

  /// 端末単位の匿名ID(未初期化なら null)。
  String? get uid => _uid;

  /// 匿名IDを保持しているか。
  bool get isSignedIn => _uid != null && _uid!.isNotEmpty;

  /// 端末の匿名IDを(再)確保する。
  /// 保存済みなら再利用し、無ければ新規発行して保存する。
  /// 失敗しても投稿機能自体は動くよう、例外は握りつぶす。
  Future<String?> ensureSignedIn() async {
    if (_uid != null && _uid!.isNotEmpty) {
      lastError = null;
      return _uid;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_kDeviceId);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await prefs.setString(_kDeviceId, id);
        if (kDebugMode) {
          debugPrint('Device anonymous id created: $id');
        }
      }
      _uid = id;
      lastError = null;
      return _uid;
    } catch (e) {
      lastError = e.toString();
      if (kDebugMode) {
        debugPrint('Device anonymous id init failed: $e');
      }
      return null;
    }
  }
}
