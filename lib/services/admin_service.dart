import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import 'audit_repository.dart';

/// 監査ログ1件。管理者が行った操作(資源の登録・一括アップロード等)を記録する。
class AuditEntry {
  /// 操作の種類(例: 'admin_login', 'resource_add', 'resource_bulk_upload')
  final String action;

  /// 補足説明(例: '消火器 4丁目第1', 'CSV 12件登録')
  final String detail;

  /// 操作した管理者名(自治会役員名など)。未設定なら空。
  final String adminName;

  final DateTime at;

  const AuditEntry({
    required this.action,
    required this.detail,
    required this.adminName,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
        'action': action,
        'detail': detail,
        'adminName': adminName,
        'at': at.toIso8601String(),
      };

  factory AuditEntry.fromMap(Map<dynamic, dynamic> map) => AuditEntry(
        action: (map['action'] as String?) ?? '',
        detail: (map['detail'] as String?) ?? '',
        adminName: (map['adminName'] as String?) ?? '',
        at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// 管理者(自治会役員)認証を強化して担うサービス(案Y)。
///
/// 従来の「合言葉の平文比較のみ」から、次の4点を強化した:
///  1. 合言葉を SHA-256 ハッシュで保持し、平文をソースに埋め込まない。
///  2. 管理者ごとに「役員名/自治会名」を登録し、資源データや監査ログに刻む。
///  3. セッション有効期限(既定60分)を設け、期限切れで自動的に権限を失効させる。
///  4. 端末ローカルに監査ログを蓄積し、いつ誰が何をしたか追跡できる。
///
/// 注意: Firebase Auth を用いないため、サーバー側で書き込み権限を厳密に
/// 強制するものではない。あくまで実証運用段階での「権限の見える化」と
/// 「共有端末での付けっぱなし防止」「操作追跡」を目的とする。
class AdminService {
  static const _kAdmin = 'is_admin';
  static const _kAdminName = 'admin_name';
  static const _kAdminExpiry = 'admin_expiry'; // ISO8601

  /// 監査ログの保存先(Firestore 一本化 = 案A)。
  ///
  /// セッション/認証状態は端末ローカル(SharedPreferences)のままだが、
  /// 「いつ誰が何をしたか」の操作ログは Firestore に集約し、端末を
  /// またいで永続化・共有できるようにする。
  final AuditRepository auditRepository;

  AdminService({AuditRepository? auditRepository})
      : auditRepository = auditRepository ?? AuditRepository();

  /// 入力された合言葉が正しいか(ハッシュ照合)。
  static bool verifyPassphrase(String input) {
    final digest = sha256.convert(utf8.encode(input.trim())).toString();
    return digest == AppConstants.adminPassphraseHash;
  }

  /// 管理者モードを有効化する。合言葉が正しければ true。
  /// [adminName] は登録する役員名/自治会名(任意)。
  Future<bool> login(String passphrase, String adminName) async {
    if (!verifyPassphrase(passphrase)) return false;
    final prefs = await SharedPreferences.getInstance();
    final expiry =
        DateTime.now().add(Duration(minutes: AppConstants.adminSessionMinutes));
    await prefs.setBool(_kAdmin, true);
    await prefs.setString(_kAdminName, adminName.trim());
    await prefs.setString(_kAdminExpiry, expiry.toIso8601String());
    await _appendAudit(AuditEntry(
      action: 'admin_login',
      detail: '管理者モード開始',
      adminName: adminName.trim(),
      at: DateTime.now(),
    ));
    return true;
  }

  /// 管理者モードを解除する。
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kAdminName) ?? '';
    await prefs.setBool(_kAdmin, false);
    await prefs.remove(_kAdminExpiry);
    await _appendAudit(AuditEntry(
      action: 'admin_logout',
      detail: '管理者モード終了',
      adminName: name,
      at: DateTime.now(),
    ));
  }

  /// 現在、有効な管理者セッションがあるか(期限切れは false として扱い、
  /// 併せてフラグを落とす)。
  Future<bool> isActive() async {
    final prefs = await SharedPreferences.getInstance();
    final isAdmin = prefs.getBool(_kAdmin) ?? false;
    if (!isAdmin) return false;
    final expiryStr = prefs.getString(_kAdminExpiry);
    final expiry = DateTime.tryParse(expiryStr ?? '');
    if (expiry == null || DateTime.now().isAfter(expiry)) {
      // 期限切れ → 自動失効
      await prefs.setBool(_kAdmin, false);
      await prefs.remove(_kAdminExpiry);
      return false;
    }
    return true;
  }

  /// 登録済みの管理者名(役員名/自治会名)。未設定なら空文字。
  Future<String> loadAdminName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAdminName) ?? '';
  }

  /// セッションの残り時間。無効なら null。
  Future<Duration?> remaining() async {
    final prefs = await SharedPreferences.getInstance();
    final isAdmin = prefs.getBool(_kAdmin) ?? false;
    if (!isAdmin) return null;
    final expiry = DateTime.tryParse(prefs.getString(_kAdminExpiry) ?? '');
    if (expiry == null) return null;
    final diff = expiry.difference(DateTime.now());
    return diff.isNegative ? null : diff;
  }

  /// 監査ログに1件追記する(公開API — 資源登録などから呼ぶ)。
  Future<void> logAction(String action, String detail) async {
    final name = await loadAdminName();
    await _appendAudit(AuditEntry(
      action: action,
      detail: detail,
      adminName: name,
      at: DateTime.now(),
    ));
  }

  /// 監査ログを新しい順に取得する(Firestore から)。
  Future<List<AuditEntry>> loadAudit() => auditRepository.loadAll();

  /// 監査ログを1件追記する(Firestore へ)。
  Future<void> _appendAudit(AuditEntry entry) =>
      auditRepository.append(entry);
}
