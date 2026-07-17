import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/pin.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/attachment_view.dart';
import '../widgets/badges.dart';

/// ピン詳細を表示するボトムシート。ステータス更新・削除ができる。
class PinDetailSheet extends StatelessWidget {
  final String pinId;
  const PinDetailSheet({super.key, required this.pinId});

  static Future<void> show(BuildContext context, String pinId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PinDetailSheet(pinId: pinId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F5F3),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Consumer<AppState>(
            builder: (context, state, _) {
              final pin = state.pinById(pinId);
              if (pin == null) {
                return const Center(child: Text('このピンは削除されました'));
              }
              return _DetailBody(pin: pin, controller: scrollController);
            },
          ),
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Pin pin;
  final ScrollController controller;
  const _DetailBody({required this.pin, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              Row(
                children: [
                  TypeBadge(type: pin.type),
                  const SizedBox(width: 8),
                  PriorityChip(priority: pin.priority),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') _confirmDelete(context, pin);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('削除'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                pin.title.isEmpty ? '(タイトルなし)' : pin.title,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w800, height: 1.3),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 16, color: Colors.black45),
                  const SizedBox(width: 4),
                  Text(pin.authorName,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(width: 12),
                  Icon(Icons.schedule_rounded,
                      size: 15, color: Colors.black45),
                  const SizedBox(width: 4),
                  Text(relativeTime(pin.createdAt),
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
              if (pin.comment.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: Text(pin.comment,
                      style: const TextStyle(fontSize: 14.5, height: 1.6)),
                ),
              ],
              if (pin.attachments.isNotEmpty) ...[
                const SizedBox(height: 18),
                _sectionLabel(Icons.attachment_rounded, '添付'),
                const SizedBox(height: 10),
                AttachmentGallery(attachments: pin.attachments),
              ],
              const SizedBox(height: 20),
              _sectionLabel(Icons.timeline_rounded, '対応ステータス'),
              const SizedBox(height: 12),
              _StatusStepper(pin: pin),
              const SizedBox(height: 20),
              _sectionLabel(Icons.place_outlined, '位置'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        size: 18, color: Colors.black45),
                    const SizedBox(width: 8),
                    Text(formatLatLng(pin.lat, pin.lng),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700)),
        ],
      );

  void _confirmDelete(BuildContext context, Pin pin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ピンを削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<AppState>().deletePin(pin.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

/// ステータスを進める/戻すステッパー。
/// 種別([PinType.availableStatuses])に応じて選べるステータスが変わる。
class _StatusStepper extends StatelessWidget {
  final Pin pin;
  const _StatusStepper({required this.pin});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    // 種別ごとの選択可能なステータス一覧(順序どおり)
    final statuses = pin.type.availableStatuses;
    // 現在ステータスの、この一覧内での位置(見つからなければ0)
    final currentIndex =
        statuses.indexOf(pin.status).clamp(0, statuses.length - 1);

    return Column(
      children: [
        Row(
          children: List.generate(statuses.length, (i) {
            final s = statuses[i];
            final active = i <= currentIndex;
            final isLast = i == statuses.length - 1;
            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: active ? s.color : Colors.black12,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(s.icon,
                        size: 16,
                        color: active ? Colors.white : Colors.black38),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i < currentIndex
                            ? statuses[i + 1].color
                            : Colors.black12,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statuses.map((s) {
            final selected = s == pin.status;
            return ChoiceChip(
              label: Text(s.label),
              selected: selected,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected ? Colors.white : s.color,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              selectedColor: s.color,
              backgroundColor: s.color.withValues(alpha: 0.1),
              side: BorderSide(color: s.color.withValues(alpha: 0.5)),
              onSelected: (_) {
                if (!selected) {
                  state.updateStatus(pin, s);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ステータスを「${s.label}」に更新しました'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
