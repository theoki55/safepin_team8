import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/pin.dart';
import '../services/pin_repository.dart';
import '../services/settings_service.dart';

/// アプリ全体の状態管理。
/// ピン一覧、フィルタ、モード、投稿者名を保持する。
class AppState extends ChangeNotifier {
  final PinRepository repository;
  final SettingsService settings;

  AppState({required this.repository, required this.settings});

  // ---- データ ----
  List<Pin> _pins = [];
  bool _loading = true;
  bool get loading => _loading;

  // ---- 設定 ----
  AppMode _mode = AppMode.normal;
  AppMode get mode => _mode;

  String _authorName = '';
  String get authorName => _authorName;

  // ---- フィルタ ----
  final Set<PinType> _typeFilter = {...PinType.values};
  final Set<PinStatus> _statusFilter = {...PinStatus.values};
  bool _hideResolved = false;

  Set<PinType> get typeFilter => _typeFilter;
  Set<PinStatus> get statusFilter => _statusFilter;
  bool get hideResolved => _hideResolved;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await repository.init();
    _mode = await settings.loadMode();
    _authorName = await settings.loadAuthorName();
    _pins = await repository.getAll();
    _loading = false;
    notifyListeners();
  }

  // ---- ピン一覧(フィルタ適用済み) ----
  List<Pin> get allPins => List.unmodifiable(_pins);

  List<Pin> get filteredPins {
    return _pins.where((p) {
      if (!_typeFilter.contains(p.type)) return false;
      if (!_statusFilter.contains(p.status)) return false;
      if (_hideResolved && p.status == PinStatus.resolved) return false;
      return true;
    }).toList();
  }

  int countByType(PinType type) => _pins.where((p) => p.type == type).length;

  int get unresolvedCount =>
      _pins.where((p) => p.status != PinStatus.resolved).length;

  int get urgentNeedCount => _pins
      .where((p) =>
          p.type == PinType.need &&
          p.priority == PinPriority.high &&
          p.status != PinStatus.resolved)
      .length;

  // ---- CRUD ----
  Future<void> addPin(Pin pin) async {
    await repository.add(pin);
    _pins.insert(0, pin);
    notifyListeners();
  }

  Future<void> updatePin(Pin pin) async {
    await repository.update(pin);
    final i = _pins.indexWhere((p) => p.id == pin.id);
    if (i >= 0) {
      _pins[i] = pin;
    }
    notifyListeners();
  }

  Future<void> updateStatus(Pin pin, PinStatus status) async {
    await updatePin(pin.copyWith(status: status, updatedAt: DateTime.now()));
  }

  Future<void> deletePin(String id) async {
    await repository.delete(id);
    _pins.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Pin? pinById(String id) {
    for (final p in _pins) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---- 設定変更 ----
  Future<void> setMode(AppMode mode) async {
    _mode = mode;
    await settings.saveMode(mode);
    notifyListeners();
  }

  Future<void> toggleMode() async {
    await setMode(_mode == AppMode.normal ? AppMode.disaster : AppMode.normal);
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

  void resetFilters() {
    _typeFilter
      ..clear()
      ..addAll(PinType.values);
    _statusFilter
      ..clear()
      ..addAll(PinStatus.values);
    _hideResolved = false;
    notifyListeners();
  }

  bool get isFiltered =>
      _typeFilter.length != PinType.values.length ||
      _statusFilter.length != PinStatus.values.length ||
      _hideResolved;
}
