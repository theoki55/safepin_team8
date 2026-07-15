/// 日時を「たった今 / 5分前 / 3時間前 / M/d HH:mm」で表示する。
String relativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'たった今';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
  if (diff.inHours < 24) return '${diff.inHours}時間前';
  if (diff.inDays < 7) return '${diff.inDays}日前';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
}

/// 緯度経度を短く表示。
String formatLatLng(double lat, double lng) =>
    '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
