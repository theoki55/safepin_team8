import 'package:geolocator/geolocator.dart';

/// 現在地取得サービス。権限拒否・無効時はエラーメッセージ付きで返す。
class LocationResult {
  final double? lat;
  final double? lng;
  final String? error;

  const LocationResult({this.lat, this.lng, this.error});

  bool get success => lat != null && lng != null;
}

class LocationService {
  Future<LocationResult> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(error: '位置情報サービスが無効です。設定を確認してください。');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(error: '位置情報の利用が許可されませんでした。');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
            error: '位置情報が恒久的に拒否されています。ブラウザ/端末の設定から許可してください。');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult(lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      return LocationResult(error: '現在地を取得できませんでした（$e）');
    }
  }
}
