import 'package:flutter/material.dart';

import '../models/resource.dart';

/// 地図上の地域資源(RESOURCE)マーカー。
///
/// NEED/OFFER/INFO の「涙型ピン」と視覚的に区別するため、
/// 資源は角丸四角(タグ型)のバッジで表す。カテゴリ色とアイコンを使う。
/// 利用不可(available=false)の資源は色を薄くし、×バッジを付ける。
class ResourceMarker extends StatelessWidget {
  final Resource resource;
  const ResourceMarker({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    final color = resource.category.color;
    final off = !resource.available;
    return SizedBox(
      width: 40,
      height: 44,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: off ? color.withValues(alpha: 0.4) : color,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(resource.category.icon, color: Colors.white, size: 18),
          ),
          if (off)
            Positioned(
              right: 0,
              top: -2,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.do_not_disturb_on_rounded,
                    size: 14, color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }
}
