import 'package:flutter/material.dart';

import '../models/pin.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import 'badges.dart';

/// 一覧・地図下部で使うピンのサマリーカード。
class PinCard extends StatelessWidget {
  final Pin pin;
  final VoidCallback onTap;
  const PinCard({super.key, required this.pin, required this.onTap});

  /// 「古い情報」が「役に立った」を上回り、規定件数を超えているか。
  bool get _possiblyOutdated =>
      pin.outdatedBy.length > pin.helpfulBy.length &&
      pin.outdatedBy.length >= AppConstants.outdatedWarnThreshold;

  Widget _outdatedBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange),
            SizedBox(width: 2),
            Text('古い可能性',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB26A00))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TypeBadge(type: pin.type, compact: true),
                  const SizedBox(width: 6),
                  PriorityChip(priority: pin.priority),
                  if (_possiblyOutdated) ...[
                    const SizedBox(width: 6),
                    _outdatedBadge(),
                  ],
                  const Spacer(),
                  Text(
                    relativeTime(pin.createdAt),
                    style: const TextStyle(color: Colors.black45, fontSize: 11.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pin.title.isEmpty ? '(タイトルなし)' : pin.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              if (pin.comment.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  pin.comment,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  StatusChip(status: pin.status, compact: true),
                  const Spacer(),
                  if (pin.imageCount > 0) ...[
                    const Icon(Icons.image_outlined,
                        size: 15, color: Colors.black45),
                    const SizedBox(width: 2),
                    Text('${pin.imageCount}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                    const SizedBox(width: 8),
                  ],
                  if (pin.fileCount > 0) ...[
                    const Icon(Icons.attach_file_rounded,
                        size: 15, color: Colors.black45),
                    const SizedBox(width: 2),
                    Text('${pin.fileCount}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                    const SizedBox(width: 8),
                  ],
                  Icon(Icons.person_outline_rounded,
                      size: 14, color: Colors.black38),
                  const SizedBox(width: 2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: Text(
                      pin.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
