import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/pin.dart';
import '../services/auth_service.dart';
import '../services/pin_repository.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';

/// アプリ全体の状態管理。
/// ピン一覧、フィルタ、モード、投稿者名を保持する。
class AppState extends ChangeNotifier {
  final PinRepository repository;
  final SettingsService settings;
  final AuthService auth;

  AppState({
    required this.repository,
    required this.settings,
    required this.auth,
  });

  /// 端末ごとの匿名ID(未認証なら空文字)。
  String get currentUid => auth.uid ?? '';

  /// 匿名サインインを(再)確保する。既にサインイン済みなら即返る。
  /// 投稿直前など、uid を確実に付けたいタイミングで呼ぶ。
  Future<void> ensureSignedIn() async {
    if ((auth.uid ?? '').isNotEmpty) return;
    await auth.ensureSignedIn();
    notifyListeners();
  }

  /// このピンが「自分の投稿」かどうか。
  /// authorUid が一致する場合のみ true。
  /// (過去データなど authorUid が空のピンは、誰でも操作できるよう true 扱い)
  bool isMine(Pin pin) {
    if (pin.authorUid.isEmpty) return true;
    return pin.authorUid == currentUid;
  }

  /// このピンを編集/削除できるか。
  /// 管理者(自治会役員)はすべての投稿を、一般利用者は自分の投稿のみ操作可。
  bool canManage(Pin pin) => _isAdmin || isMine(pin);

  /// 「確実に自分の投稿」か。authorUid が空のピン(投稿者不明の過去データ)は
  /// 自分の投稿とはみなさない。通報ボタンの表示制御などに使う。
  bool isStrictlyMine(Pin pin) =>
      pin.authorUid.isNotEmpty && pin.authorUid == currentUid;

  /// 現在のユーザーが削除・編集できるピンの一覧(全モード)。
  /// 一般利用者は自分の投稿(+投稿者不明の過去データ)、管理者は全件。
  List<Pin> get manageablePins =>
      _pins.where(canManage).toList();

  // ---- 管理者(自治会役員)モード ----
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  /// 合言葉を照合して管理者モードを有効にする。成功したら true。
  Future<bool> tryEnableAdmin(String passphrase) async {
    if (passphrase.trim() != AppConstants.adminPassphrase) return false;
    _isAdmin = true;
    await settings.saveIsAdmin(true);
    notifyListeners();
    return true;
  }

  /// 管理者モードを解除する。
  Future<void> disableAdmin() async {
    _isAdmin = false;
    await settings.saveIsAdmin(false);
    notifyListeners();
  }

  // ---- データ ----
  List<Pin> _pins = [];
  bool _loading = true;
  bool get loading => _loading;

  /// リアルタイム同期を使うかどうか(repository.watch() が非null)
  StreamSubscription<List<Pin>>? _pinsSub;
  bool _realtime = false;
  bool get realtime => _realtime;

  // ---- 設定 ----
  AppMode _mode = AppMode.normal;
  AppMode get mode => _mode;

  String _authorName = '';
  String get authorName => _authorName;

  // ---- フィルタ ----
  final Set<PinType> _typeFilter = {...PinType.values};
  final Set<PinStatus> _statusFilter = {...PinStatus.values};
  bool _hideResolved = false;

  /// 全モードのピンを表示するか。
  /// false のときは現在のアプリモード([_mode])と一致するピンのみ表示する。
  bool _showAllModes = false;

  Set<PinType> get typeFilter => _typeFilter;
  Set<PinStatus> get statusFilter => _statusFilter;
  bool get hideResolved => _hideResolved;
  bool get showAllModes => _showAllModes;

  /// モードに応じた種別の推奨(強調)フィルタ。
  /// - 災害モード: NEED を強調(NEED/OFFER を表示、INFO は隠す)
  /// - 平時モード: INFO 中心(INFO/OFFER を表示、NEED は隠す)
  static Set<PinType> _recommendedTypeFilter(AppMode mode) {
    switch (mode) {
      case AppMode.disaster:
        return {PinType.need, PinType.offer};
      case AppMode.normal:
        return {PinType.info, PinType.offer};
    }
  }

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await repository.init();
    _mode = await settings.loadMode();
    _authorName = await settings.loadAuthorName();
    _isAdmin = await settings.loadIsAdmin();
    // 起動時、現在のモードに応じた推奨フィルタを適用する。
    _applyRecommendedFilter(_mode);

    // リアルタイム同期が可能ならストリーム購読、不可なら一括取得
    final stream = repository.watch();
    if (stream != null) {
      _realtime = true;
      // 初回の1件目を待ってから loading を解除する
      final completer = Completer<void>();
      _pinsSub = stream.listen(
        (pins) {
          _pins = pins;
          if (_loading) {
            _loading = false;
            if (!completer.isCompleted) completer.complete();
          }
          notifyListeners();
        },
        onError: (Object e, StackTrace st) {
          if (kDebugMode) {
            debugPrint('AppState watch error: $e');
          }
          if (_loading) {
            _loading = false;
            if (!completer.isCompleted) completer.complete();
          }
          notifyListeners();
        },
      );
      // 最大5秒待つ(接続が遅い場合でもUIをブロックしない)
      await Future.any([
        completer.future,
        Future<void>.delayed(const Duration(seconds: 5)),
      ]);
      if (_loading) {
        _loading = false;
        notifyListeners();
      }
    } else {
      _realtime = false;
      _pins = await repository.getAll();
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pinsSub?.cancel();
    super.dispose();
  }

  // ---- ピン一覧(フィルタ適用済み) ----
  List<Pin> get allPins => List.unmodifiable(_pins);

  List<Pin> get filteredPins {
    return _pins.where((p) {
      // 通報で非表示になった投稿は一般利用者には見せない(管理者には薄く表示)。
      if (p.hiddenByReports && !_isAdmin) return false;
      // モード別絞り込み: 「全モード表示」でなければ現在のモードのピンのみ
      if (!_showAllModes && p.mode != _mode) return false;
      if (!_typeFilter.contains(p.type)) return false;
      if (!_statusFilter.contains(p.status)) return false;
      if (_hideResolved && p.status == PinStatus.resolved) return false;
      return true;
    }).toList();
  }

  /// 現在のモードで表示対象になるピン(種別フィルタ等は無視、モードのみ考慮)。
  Iterable<Pin> get _pinsForCurrentMode =>
      _showAllModes ? _pins : _pins.where((p) => p.mode == _mode);

  int countByType(PinType type) =>
      _pinsForCurrentMode.where((p) => p.type == type).length;

  int get unresolvedCount =>
      _pinsForCurrentMode.where((p) => p.status != PinStatus.resolved).length;

  int get urgentNeedCount => _pinsForCurrentMode
      .where((p) =>
          p.type == PinType.need &&
          p.priority == PinPriority.high &&
          p.status != PinStatus.resolved)
      .length;

  // ---- CRUD ----
  // リアルタイム同期時は snapshot が _pins を更新するため、
  // ローカルリストは直接操作しない。非リアルタイム時のみ手動で更新する。
  Future<void> addPin(Pin pin) async {
    await repository.add(pin);
    if (!_realtime) {
      _pins.insert(0, pin);
      notifyListeners();
    }
  }

  Future<void> updatePin(Pin pin) async {
    await repository.update(pin);
    if (!_realtime) {
      final i = _pins.indexWhere((p) => p.id == pin.id);
      if (i >= 0) {
        _pins[i] = pin;
      }
      notifyListeners();
    }
  }

  Future<void> updateStatus(Pin pin, PinStatus status) async {
    await updatePin(pin.copyWith(status: status, updatedAt: DateTime.now()));
  }

  // ---- ステップB: 通報 ----

  /// 自分がこの投稿を通報済みか。
  bool hasReported(Pin pin) => pin.reportedBy.contains(currentUid);

  /// 通報件数(自動非表示の判定に使う)。
  int reportCount(Pin pin) => pin.reportedBy.length;

  /// この投稿を通報する。既に通報済みなら何もしない。
  /// 通報件数が閾値に達したら自動的に非表示にする。
  Future<void> reportPin(Pin pin) async {
    await ensureSignedIn();
    final uid = currentUid;
    if (uid.isEmpty || pin.reportedBy.contains(uid)) return;
    final updated = List<String>.from(pin.reportedBy)..add(uid);
    final hide =
        updated.length >= AppConstants.reportHideThreshold || pin.hiddenByReports;
    await updatePin(pin.copyWith(
      reportedBy: updated,
      hiddenByReports: hide,
      updatedAt: DateTime.now(),
    ));
  }

  /// 管理者が非表示を解除する(通報リセット)。
  Future<void> unhidePin(Pin pin) async {
    if (!_isAdmin) return;
    await updatePin(pin.copyWith(
      reportedBy: const [],
      hiddenByReports: false,
      updatedAt: DateTime.now(),
    ));
  }

  // ---- ステップB: 信頼度シグナル ----

  bool hasConfirmed(Pin pin) => pin.confirmedBy.contains(currentUid);
  bool hasHelpful(Pin pin) => pin.helpfulBy.contains(currentUid);
  bool hasOutdated(Pin pin) => pin.outdatedBy.contains(currentUid);

  /// 「古い可能性」の注意表示を出すべきか。
  bool isPossiblyOutdated(Pin pin) =>
      pin.outdatedBy.length > pin.helpfulBy.length &&
      pin.outdatedBy.length >= AppConstants.outdatedWarnThreshold;

  /// 「現地確認済」をトグルする。一定人数が押したら未確認→現地確認済に自動昇格。
  Future<void> toggleConfirm(Pin pin) async {
    await ensureSignedIn();
    final uid = currentUid;
    if (uid.isEmpty) return;
    final list = List<String>.from(pin.confirmedBy);
    if (list.contains(uid)) {
      list.remove(uid);
    } else {
      list.add(uid);
    }
    // 未確認の投稿で規定人数に達したら現地確認済へ引き上げる。
    var newStatus = pin.status;
    if (pin.status == PinStatus.unconfirmed &&
        list.length >= AppConstants.confirmAutoThreshold &&
        pin.type.supportsStatus(PinStatus.confirmed)) {
      newStatus = PinStatus.confirmed;
    }
    await updatePin(pin.copyWith(
      confirmedBy: list,
      status: newStatus,
      updatedAt: DateTime.now(),
    ));
  }

  /// 「役に立った」をトグルする。
  Future<void> toggleHelpful(Pin pin) async {
    await ensureSignedIn();
    final uid = currentUid;
    if (uid.isEmpty) return;
    final list = List<String>.from(pin.helpfulBy);
    list.contains(uid) ? list.remove(uid) : list.add(uid);
    await updatePin(pin.copyWith(helpfulBy: list, updatedAt: DateTime.now()));
  }

  /// 「古い情報」をトグルする。
  Future<void> toggleOutdated(Pin pin) async {
    await ensureSignedIn();
    final uid = currentUid;
    if (uid.isEmpty) return;
    final list = List<String>.from(pin.outdatedBy);
    list.contains(uid) ? list.remove(uid) : list.add(uid);
    await updatePin(pin.copyWith(outdatedBy: list, updatedAt: DateTime.now()));
  }

  Future<void> deletePin(String id) async {
    await repository.delete(id);
    if (!_realtime) {
      _pins.removeWhere((p) => p.id == id);
      notifyListeners();
    }
  }

  /// 複数ピンを一括削除する。削除できた件数を返す。
  /// 権限(自分の投稿 or 管理者)のないピンは安全のためスキップする。
  Future<int> deletePins(Iterable<String> ids) async {
    var deleted = 0;
    for (final id in ids) {
      final pin = pinById(id);
      // 権限チェック: 該当ピンが見つかり、かつ管理できる場合のみ削除。
      if (pin != null && !canManage(pin)) {
        if (kDebugMode) debugPrint('deletePins skipped (no permission): $id');
        continue;
      }
      try {
        await repository.delete(id);
        if (!_realtime) _pins.removeWhere((p) => p.id == id);
        deleted++;
      } catch (e) {
        if (kDebugMode) debugPrint('deletePins error for $id: $e');
      }
    }
    if (!_realtime) notifyListeners();
    return deleted;
  }

  /// 複数ピンを一括追加(インポート)する。追加できた件数を返す。
  Future<int> addPins(List<Pin> pins) async {
    var added = 0;
    for (final pin in pins) {
      try {
        await repository.add(pin);
        if (!_realtime) _pins.insert(0, pin);
        added++;
      } catch (e) {
        if (kDebugMode) debugPrint('addPins error for ${pin.id}: $e');
      }
    }
    if (!_realtime) notifyListeners();
    return added;
  }

  Pin? pinById(String id) {
    for (final p in _pins) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---- 設定変更 ----
  Future<void> setMode(AppMode mode) async {
    final changed = _mode != mode;
    _mode = mode;
    await settings.saveMode(mode);
    // モードが変わったら推奨フィルタを再適用する。
    if (changed) {
      _applyRecommendedFilter(mode);
    }
    notifyListeners();
  }

  Future<void> toggleMode() async {
    await setMode(_mode == AppMode.normal ? AppMode.disaster : AppMode.normal);
  }

  /// モードに応じた推奨フィルタを適用する(モード連動フィルタ)。
  void _applyRecommendedFilter(AppMode mode) {
    final recommended = _recommendedTypeFilter(mode);
    _typeFilter
      ..clear()
      ..addAll(recommended);
    // ステータス・対応済み表示はモード切替では変更しない。
  }

  Future<void> setAuthorName(String name) async {
    _authorName = name;
    await settings.saveAuthorName(name);
    notifyListeners();
  }

  // ---- フィルタ操作 ----
  void toggleTypeFilter(PinType type) {
    if (_typeFilter.contains(type)) {
      _typeFilter.remove(type);
    } else {
      _typeFilter.add(type);
    }
    notifyListeners();
  }

  void toggleStatusFilter(PinStatus status) {
    if (_statusFilter.contains(status)) {
      _statusFilter.remove(status);
    } else {
      _statusFilter.add(status);
    }
    notifyListeners();
  }

  void setHideResolved(bool value) {
    _hideResolved = value;
    notifyListeners();
  }

  void setShowAllModes(bool value) {
    _showAllModes = value;
    notifyListeners();
  }

  /// 種別フィルタを現在のモードの推奨状態に戻す。
  void applyRecommendedFilterForCurrentMode() {
    _applyRecommendedFilter(_mode);
    notifyListeners();
  }

  void resetFilters() {
    _typeFilter
      ..clear()
      ..addAll(PinType.values);
    _statusFilter
      ..clear()
      ..addAll(PinStatus.values);
    _hideResolved = false;
    _showAllModes = false;
    notifyListeners();
  }

  bool get isFiltered =>
      _typeFilter.length != PinType.values.length ||
      _statusFilter.length != PinStatus.values.length ||
      _hideResolved ||
      _showAllModes;
}
