import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/pin.dart';

/// 地図上のピンマーカー(涙型ピン + 種別アイコン)。
class PinMarker extends StatelessWidget {
  final Pin pin;
  final bool selected;
  const PinMarker({super.key, required this.pin, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final color = pin.type.color;
    final resolved = pin.status == PinStatus.resolved;
    final urgent = pin.priority == PinPriority.high && !resolved;

    return SizedBox(
      width: 44,
      height: 52,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // ピン本体
          _PinShape(
            color: resolved ? color.withValues(alpha: 0.45) : color,
            selected: selected,
            icon: pin.type.icon,
          ),
          // 緊急バッジ
          if (urgent)
            Positioned(
              right: 2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.priority_high_rounded,
                    size: 12, color: Color(0xFFD32F2F)),
              ),
            ),
          // 対応済チェック
          if (resolved)
            Positioned(
              right: 2,
              top: -2,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    size: 15, color: Color(0xFF2E7D32)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinShape extends StatelessWidget {
  final Color color;
  final bool selected;
  final IconData icon;
  const _PinShape(
      {required this.color, required this.selected, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scale = selected ? 1.15 : 1.0;
    return Transform.scale(
      scale: scale,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.white,
                width: selected ? 3 : 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          // 三角形の尻尾
          Transform.translate(
            offset: const Offset(0, -4),
            child: CustomPaint(
              size: const Size(14, 10),
              painter: _TrianglePainter(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
