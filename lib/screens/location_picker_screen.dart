import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/community.dart';
import '../providers/app_state.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import '../utils/format.dart';

/// 地図をタップして位置を選択する画面。中央固定ピン方式。
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();
  final _locationService = LocationService();
  late LatLng _center;
  late Area _area;
  late bool _hasCheck;
  late String _communityName;
  late double _initialZoom;
  bool _locating = false;
  bool _inArea = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _area = state.area;
    _hasCheck = state.hasAreaCheck;
    _communityName = state.community.name;
    _center = widget.initial ?? state.mapCenter;
    // 丁目単位は近接(16)、市区町村など広域はコミュニティの初期ズームを使う。
    _initialZoom = _hasCheck ? 16.0 : state.mapZoom;
    // 判定を持たないコミュニティ(市区町村全体)では常に「内」扱い。
    _inArea = !_hasCheck || _area.contains(_center);
  }

  /// 地図移動時: 中心座標と区域内/外を更新して再描画する。
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final c = camera.center;
    final nowIn = !_hasCheck || _area.contains(c);
    if (!mounted) return;
    setState(() {
      _center = c;
      _inArea = nowIn;
    });
  }

  Future<void> _goToCurrent() async {
    setState(() => _locating = true);
    final r = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (r.success) {
      final p = LatLng(r.lat!, r.lng!);
      _mapController.move(p, 17);
      setState(() {
        _center = p;
        _inArea = !_hasCheck || _area.contains(p);
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.error ?? '取得失敗')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('地図で位置を指定')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _initialZoom,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.osmTileUrl,
                userAgentPackageName: AppConstants.osmUserAgent,
                maxZoom: 19,
              ),
              // サービス対象区域(丁目ポリゴン)の境界を薄い緑で表示。
              // 市区町村全体などポリゴンを持たない場合は描画しない。
              if (_area.polygons.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    for (final area in _area.polygons)
                      Polygon(
                        points: area.points,
                        color: const Color(AppConstants.serviceAreaColorValue)
                            .withValues(alpha: 0.08),
                        borderColor:
                            const Color(AppConstants.serviceAreaColorValue)
                                .withValues(alpha: 0.7),
                        borderStrokeWidth: 2,
                      ),
                  ],
                ),
            ],
          ),
          // 中央固定ピン(区域外はオレンジで注意喚起)
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _inArea
                          ? Icons.location_on
                          : Icons.wrong_location_rounded,
                      size: 52,
                      color: _inArea
                          ? const Color(0xFFE64A2E)
                          : const Color(0xFFFF6D00),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 案内バナー
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, size: 18, color: Colors.black54),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('地図を動かして、中央のピンを立てたい場所に合わせてください',
                        style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ),
          // 現在地ボタン
          Positioned(
            right: 12,
            bottom: 96,
            child: FloatingActionButton.small(
              heroTag: 'picker_loc',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFE64A2E),
              onPressed: _locating ? null : _goToCurrent,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasCheck) ...[
                _areaBanner(),
                const SizedBox(height: 8),
              ],
              Text(formatLatLng(_center.latitude, _center.longitude),
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _center),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('この位置に決定'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 中央ピン位置が対象区域の内/外かを示す帯。
  Widget _areaBanner() {
    final bg = _inArea ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final fg = _inArea ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            _inArea ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: fg,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _inArea
                  ? '対象区域内（$_communityName）です。'
                  : '対象区域（$_communityName）の外です。'
                      'このまま決定もできますが、区域内をおすすめします。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
