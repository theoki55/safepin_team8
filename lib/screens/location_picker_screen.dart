import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _center = widget.initial ?? AppConstants.defaultCenter;
  }

  Future<void> _goToCurrent() async {
    setState(() => _locating = true);
    final r = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (r.success) {
      final p = LatLng(r.lat!, r.lng!);
      _mapController.move(p, 17);
      setState(() => _center = p);
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
              initialZoom: 16,
              onPositionChanged: (camera, hasGesture) {
                _center = camera.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.osmTileUrl,
                userAgentPackageName: AppConstants.osmUserAgent,
                maxZoom: 19,
              ),
            ],
          ),
          // 中央固定ピン
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.location_on,
                        size: 48, color: Color(0xFFE64A2E)),
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
}
