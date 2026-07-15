import 'package:flutter/material.dart';

import '../models/pin.dart';
import '../utils/format.dart';
import 'badges.dart';

/// 一覧・地図下部で使うピンのサマリーカード。
class PinCard extends StatelessWidget {
  final Pin pin;
  final VoidCallback onTap;
  const PinCard({super.key, required this.pin, required this.onTap});

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
