import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/app_state.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import '../utils/location_blur.dart';
import '../utils/service_area_data.dart';
import '../widgets/pin_marker.dart';
import 'filter_sheet.dart';
import 'pin_detail_sheet.dart';
import 'post_pin_screen.dart';

/// メインの地図画面。ピンの表示・投稿・詳細表示の起点。
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _locationService = LocationService();
  bool _locating = false;

  Future<void> _goToCurrent() async {
    setState(() => _locating = true);
    final r = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (r.success) {
      _mapController.move(LatLng(r.lat!, r.lng!), 16);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.error ?? '取得失敗')));
    }
  }

  Future<void> _openPost({LatLng? location}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostPinScreen(initialLocation: location),
      ),
    );
  }

  void _onLongPress(LatLng point) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('この場所にピンを立てますか？',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_rounded,
                  color: Color(0xFFE64A2E)),
              title: const Text('この場所にピンを立てる'),
              onTap: () {
                Navigator.pop(context);
                _openPost(location: point);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('キャンセル'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final pins = state.filteredPins;
        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: AppConstants.defaultCenter,
                initialZoom: AppConstants.defaultZoom,
                onLongPress: (tapPosition, point) => _onLongPress(point),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConstants.osmTileUrl,
                  userAgentPackageName: AppConstants.osmUserAgent,
                  maxZoom: 19,
                ),
                // サービス対象区域(下目黒4・5・6丁目)の境界を薄い緑で表示。
                PolygonLayer(
                  polygons: [
                    for (final area in kServiceAreaPolygons)
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
                // ぼかし円: NEED/OFFER は自宅等と結びつくため、
                // 正確な位置ではなく「このあたり(約150m四方)」を示す円を描く。
                CircleLayer(
                  circles: [
                    for (final pin in pins)
                      if (LocationBlur.isBlurred(pin))
                        CircleMarker(
                          point: LocationBlur.displayLatLng(pin),
                          radius: LocationBlur.circleRadiusMeters,
                          useRadiusInMeter: true,
                          color: pin.type.color.withValues(alpha: 0.14),
                          borderColor: pin.type.color.withValues(alpha: 0.5),
                          borderStrokeWidth: 1.5,
                        ),
                  ],
                ),
                MarkerLayer(
                  markers: pins.map((pin) {
                    return Marker(
                      point: LocationBlur.displayLatLng(pin),
                      width: 44,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => PinDetailSheet.show(context, pin.id),
                        child: PinMarker(pin: pin),
                      ),
                    );
                  }).toList(),
                ),
                // OSM 帰属表示(利用規約)
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            // 上部: モードバナー & 統計
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopOverlay(state: state),
            ),
            // 右下: 現在地 & 追加
            Positioned(
              right: 14,
              bottom: 24,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_loc',
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
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'map_add',
                    onPressed: () => _openPost(),
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('ピンを立てる'),
                  ),
                ],
              ),
            ),
            // 左下: 凡例 & フィルタ
            Positioned(
              left: 14,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterButton(
                    active: state.isFiltered,
                    onTap: () => FilterSheet.show(context),
                  ),
                  const SizedBox(height: 10),
                  const _Legend(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopOverlay extends StatelessWidget {
  final AppState state;
  const _TopOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    final disaster = state.mode == AppMode.disaster;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          children: [
            if (disaster)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('災害モード：SOS・安否・物資ニーズを優先表示',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5)),
                  ],
                ),
              ),
            _StatsBar(state: state),
          ],
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final AppState state;
  const _StatsBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          _stat(PinType.need, state.countByType(PinType.need)),
          _divider(),
          _stat(PinType.offer, state.countByType(PinType.offer)),
          _divider(),
          _stat(PinType.info, state.countByType(PinType.info)),
          _divider(),
          Expanded(
            child: Column(
              children: [
                Text('${state.urgentNeedCount}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFFD32F2F))),
                const Text('緊急',
                    style: TextStyle(fontSize: 10.5, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(PinType type, int count) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(type.icon, size: 14, color: type.color),
              const SizedBox(width: 3),
              Text('$count',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: type.color)),
            ],
          ),
          Text(type.shortLabel,
              style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 28, color: Colors.black12);
}

class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFE64A2E) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.tune_rounded,
                  size: 18, color: active ? Colors.white : Colors.black87),
              const SizedBox(width: 6),
              Text('絞り込み',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: PinType.values.map((t) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration:
                      BoxDecoration(color: t.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(t.shortLabel,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
