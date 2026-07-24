import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/community.dart';
import '../models/enums.dart';
import '../models/pin.dart';
import '../models/resource.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/community_service.dart';
import '../services/pin_repository.dart';
import '../services/resource_repository.dart';
import '../services/settings_service.dart';
import '../utils/communities.dart';
import '../utils/constants.dart';

/// アプリ全体の状態管理。
/// ピン一覧、フィルタ、モード、投稿者名を保持する。
class AppState extends ChangeNotifier {
  final PinRepository repository;
  final SettingsService settings;
  final AuthService auth;
  final AdminService admin;

  /// 地域資源(RESOURCE)のリポジトリ。未指定なら資源機能は無効(空)扱い。
  final ResourceRepository? resourceRepository;

  /// コミュニティ(URL固定+設定切替)の解決/保存サービス。
  final CommunityService communityService;

  AppState({
    required this.repository,
    required this.settings,
    required this.auth,
    this.resourceRepository,
    AdminService? admin,
    CommunityService? communityService,
  })  : admin = admin ?? AdminService(),
        communityService = communityService ?? CommunityService(settings);

  // ---- コミュニティ(自治会/地域) ----

  /// 現在選択中のコミュニティ。init() で解決される。
  Community _community = communityById(kDefaultCommunityId);
  Community get community => _community;
  String get communityId => _community.id;

  /// 地図初期中心(選択中コミュニティ)。
  LatLng get mapCenter => _community.center;

  /// 地図初期ズーム(選択中コミュニティ)。
  double get mapZoom => _community.zoom;

  /// 選択中コミュニティの対象区域。
  Area get area => _community.area;

  /// 区域の in/out 判定を持つか(polygon/circle のみ true)。
  bool get hasAreaCheck => _community.area.hasBoundaryCheck;

  /// 指定座標が対象区域内か(判定を持たないタイプは常に true)。
  bool isInArea(LatLng point) => _community.area.contains(point);

  /// 選択中コミュニティの区域説明テキスト。
  String get areaNote => _community.note;

  /// 選択中コミュニティを切り替える。
  /// 地図中心/区域/登録先が変わり、管理者セッションはリセットする。
  Future<void> switchCommunity(String id) async {
    if (!isValidCommunityId(id) || id == _community.id) return;
    _community = communityById(id);
    await communityService.persist(id);
    // 別地域の管理者権限を引き継がないよう、切替時にセッションを解除。
    if (_isAdmin) {
      await admin.logout();
      _isAdmin = false;
      _adminName = '';
    }
    notifyListeners();
  }

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
  // 認証・セッション・監査ログは AdminService に委譲する(案Y)。
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  /// 現在ログイン中の管理者名(役員名/自治会名)。未設定なら空文字。
  String _adminName = '';
  String get adminName2 => _adminName;

  /// 合言葉を照合して管理者モードを有効にする。成功したら true。
  /// [adminName] は登録する役員名/自治会名(任意)。
  /// 照合は現在選択中のコミュニティの合言葉ハッシュに対して行う。
  Future<bool> tryEnableAdmin(String passphrase, {String adminName = ''}) async {
    final ok = await admin.login(
      passphrase,
      adminName,
      communityId: _community.id,
      fallbackHash: _community.adminPassHash,
    );
    if (!ok) return false;
    _isAdmin = true;
    _adminName = adminName.trim();
    notifyListeners();
    return true;
  }

  /// 現在のコミュニティの管理パスワードを変更する。
  /// 現在の合言葉が正しければ新しい合言葉を保存して true。
  Future<bool> changeAdminPassword({
    required String currentPassphrase,
    required String newPassphrase,
  }) async {
    return admin.changePassphrase(
      communityId: _community.id,
      fallbackHash: _community.adminPassHash,
      currentPassphrase: currentPassphrase,
      newPassphrase: newPassphrase,
    );
  }

  /// 管理者モードを解除する。
  Future<void> disableAdmin() async {
    await admin.logout();
    _isAdmin = false;
    _adminName = '';
    notifyListeners();
  }

  /// セッション期限切れを検査し、失効していれば権限を落とす。
  /// 画面表示や管理操作の直前に呼ぶ。
  Future<void> refreshAdminSession() async {
    if (!_isAdmin) return;
    final active = await admin.isActive();
    if (!active) {
      _isAdmin = false;
      _adminName = '';
      notifyListeners();
    }
  }

  // ---- データ ----
  List<Pin> _pins = [];
  bool _loading = true;
  bool get loading => _loading;

  /// リアルタイム同期を使うかどうか(repository.watch() が非null)
  StreamSubscription<List<Pin>>? _pinsSub;
  bool _realtime = false;
  bool get realtime => _realtime;

  // ---- 地域資源(RESOURCE) ----
  List<Resource> _resources = [];
  StreamSubscription<List<Resource>>? _resourcesSub;

  /// 全資源(選択中コミュニティのみ・登録順・新しい順)。
  List<Resource> get allResources => List.unmodifiable(
      _resources.where((r) => r.communityId == _community.id));

  /// 地図に資源レイヤーを表示するか(フィルタ)。既定は表示。
  bool _showResources = true;
  bool get showResources => _showResources;

  void toggleShowResources() {
    _showResources = !_showResources;
    notifyListeners();
  }

  void setShowResources(bool value) {
    if (_showResources == value) return;
    _showResources = value;
    notifyListeners();
  }

  /// 地図/一覧に出す資源(コミュニティ+表示フィルタ適用後)。
  List<Resource> get visibleResources =>
      _showResources ? allResources : const [];

  /// 資源を1件登録する(管理者操作)。監査ログにも記録する。
  Future<void> addResource(Resource resource) async {
    final repo = resourceRepository;
    if (repo == null) return;
    // 新規登録には現在のコミュニティIDを付与する。
    final r = resource.communityId == _community.id
        ? resource
        : resource.copyWith(communityId: _community.id);
    await repo.add(r);
    if (!_resourcesRealtime) {
      _resources.insert(0, r);
      notifyListeners();
    }
    await admin.logAction(
      'resource_add',
      '${r.category.label}「${r.name}」を登録',
    );
  }

  /// 資源を更新する(管理者操作)。
  Future<void> updateResource(Resource resource) async {
    final repo = resourceRepository;
    if (repo == null) return;
    await repo.update(resource);
    if (!_resourcesRealtime) {
      final i = _resources.indexWhere((r) => r.id == resource.id);
      if (i >= 0) _resources[i] = resource;
      notifyListeners();
    }
    await admin.logAction(
      'resource_update',
      '${resource.category.label}「${resource.name}」を更新',
    );
  }

  /// 資源を削除する(管理者操作)。
  Future<void> deleteResource(String id) async {
    final repo = resourceRepository;
    if (repo == null) return;
    final target = _resources.where((r) => r.id == id).toList();
    await repo.delete(id);
    if (!_resourcesRealtime) {
      _resources.removeWhere((r) => r.id == id);
      notifyListeners();
    }
    final name = target.isNotEmpty ? target.first.name : id;
    await admin.logAction('resource_delete', '資源「$name」を削除');
  }

  /// CSV 一括アップロードで複数件を登録する(管理者操作)。成功件数を返す。
  Future<int> addResources(List<Resource> resources) async {
    final repo = resourceRepository;
    if (repo == null || resources.isEmpty) return 0;
    // 一括登録も現在のコミュニティIDを付与する。
    final tagged = resources
        .map((r) => r.communityId == _community.id
            ? r
            : r.copyWith(communityId: _community.id))
        .toList();
    final saved = await repo.addMany(tagged);
    if (!_resourcesRealtime) {
      _resources.insertAll(0, tagged);
      notifyListeners();
    }
    await admin.logAction(
      'resource_bulk_upload',
      'CSV一括アップロード $saved 件を登録',
    );
    return saved;
  }

  bool _resourcesRealtime = false;

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
    // 起動時にコミュニティを解決(URL ?c= → 保存値 → 既定)。
    _community = await communityService.resolveInitial();
    await repository.init();
    _mode = await settings.loadMode();
    _authorName = await settings.loadAuthorName();
    // 管理者セッションは有効期限つき。期限切れなら自動的に無効。
    _isAdmin = await admin.isActive();
    _adminName = _isAdmin ? await admin.loadAdminName() : '';
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

    // 地域資源(RESOURCE)の初期化(リポジトリが設定されている場合のみ)。
    await _initResources();
  }

  /// 資源リポジトリを初期化し、可能ならリアルタイム購読を開始する。
  /// 失敗しても本体(ピン)機能を止めないよう例外は握りつぶす。
  Future<void> _initResources() async {
    final repo = resourceRepository;
    if (repo == null) return;
    try {
      await repo.init();
      final stream = repo.watch();
      if (stream != null) {
        _resourcesRealtime = true;
        _resourcesSub = stream.listen(
          (list) {
            _resources = list;
            notifyListeners();
          },
          onError: (Object e, StackTrace st) {
            if (kDebugMode) debugPrint('AppState resource watch error: $e');
          },
        );
      } else {
        _resourcesRealtime = false;
        _resources = await repo.getAll();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('resource init failed (ignored): $e');
    }
  }

  @override
  void dispose() {
    _pinsSub?.cancel();
    _resourcesSub?.cancel();
    super.dispose();
  }

  // ---- ピン一覧(フィルタ適用済み) ----
  List<Pin> get allPins => List.unmodifiable(_pins);

  List<Pin> get filteredPins {
    return _pins.where((p) {
      // 選択中コミュニティのピンのみ表示(データ分離)。
      if (p.communityId != _community.id) return false;
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
  /// コミュニティ絞り込みは常に適用する。
  Iterable<Pin> get _pinsForCurrentMode => _pins.where((p) =>
      p.communityId == _community.id && (_showAllModes || p.mode == _mode));

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
    // 新規投稿には現在のコミュニティIDを付与する。
    final withCommunity = pin.communityId == _community.id
        ? pin
        : pin.copyWith(communityId: _community.id);
    await repository.add(withCommunity);
    if (!_realtime) {
      _pins.insert(0, withCommunity);
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
        final p = pin.communityId == _community.id
            ? pin
            : pin.copyWith(communityId: _community.id);
        await repository.add(p);
        if (!_realtime) _pins.insert(0, p);
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
