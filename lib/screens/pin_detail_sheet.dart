import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/pin.dart';
import '../providers/app_state.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/location_blur.dart';
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
    final state = context.read<AppState>();
    final canManage = state.canManage(pin);
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
                  // 削除は自分の投稿、または管理者のみ可能。
                  if (canManage)
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
              // 管理者向け: 通報で非表示になった投稿の警告と解除ボタン。
              if (pin.hiddenByReports && state.isAdmin) ...[
                const SizedBox(height: 14),
                _hiddenBanner(context, state, pin),
              ],
              // 「古い可能性」の注意表示。
              if (state.isPossiblyOutdated(pin)) ...[
                const SizedBox(height: 14),
                _outdatedBanner(),
              ],
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
              _sectionLabel(
                LocationBlur.isBlurred(pin)
                    ? Icons.blur_circular_rounded
                    : Icons.place_outlined,
                LocationBlur.isBlurred(pin) ? 'おおよその位置' : '位置',
              ),
              const SizedBox(height: 8),
              _locationBox(pin),
              const SizedBox(height: 22),
              _sectionLabel(Icons.groups_2_rounded, 'みんなの反応'),
              const SizedBox(height: 10),
              _ReactionBar(pin: pin),
              const SizedBox(height: 18),
              _reportRow(context, state, pin),
            ],
          ),
        ),
      ],
    );
  }

  /// 通報行(自分の投稿以外に表示)。
  Widget _reportRow(BuildContext context, AppState state, Pin pin) {
    // 確実に自分の投稿だけは通報対象にしない。
    // (authorUid が空の過去データは投稿者不明なので通報可能)
    if (state.isStrictlyMine(pin)) {
      return const SizedBox.shrink();
    }
    final reported = state.hasReported(pin);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: reported
            ? null
            : () async {
                await _confirmReport(context, state, pin);
              },
        icon: Icon(
          reported ? Icons.flag_rounded : Icons.outlined_flag_rounded,
          size: 18,
          color: reported ? Colors.grey : Colors.redAccent,
        ),
        label: Text(
          reported ? '通報済み' : 'この投稿を通報',
          style: TextStyle(
            fontSize: 13,
            color: reported ? Colors.grey : Colors.redAccent,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReport(
      BuildContext context, AppState state, Pin pin) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この投稿を通報しますか？'),
        content: Text(
          '不適切・虚偽・迷惑な内容の場合に通報してください。'
          '${AppConstants.reportHideThreshold}件の通報が集まると自動的に非表示になります。',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('通報する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await state.reportPin(pin);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('通報しました。ご協力ありがとうございます。')),
    );
  }

  Widget _hiddenBanner(BuildContext context, AppState state, Pin pin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_off_rounded,
                  size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '通報が${state.reportCount(pin)}件集まり、一般には非表示になっています（管理者のみ表示）。',
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () async {
                await state.unhidePin(pin);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('非表示を解除しました')),
                  );
                }
              },
              icon: const Icon(Icons.restore_rounded, size: 16),
              label: const Text('非表示を解除'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outdatedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '複数の人が「古い情報」と反応しています。最新の状況をご確認ください。',
              style: TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 位置表示ボックス。
  /// NEED/OFFER はプライバシー保護のため、正確な座標を伏せて
  /// 約150mグリッド中心の「おおよその位置」を示す。
  Widget _locationBox(Pin pin) {
    final blurred = LocationBlur.isBlurred(pin);
    final display = LocationBlur.displayLatLng(pin);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                blurred
                    ? Icons.blur_circular_rounded
                    : Icons.my_location_rounded,
                size: 18,
                color: Colors.black45,
              ),
              const SizedBox(width: 8),
              Text(
                formatLatLng(display.latitude, display.longitude),
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          if (blurred) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.shield_outlined,
                    size: 15, color: Color(0xFF00897B)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'プライバシー保護のため、正確な位置は伏せて'
                    'おおよそ150m四方の範囲で表示しています。',
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.black54, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
    // ステータス変更は自分の投稿、または管理者のみ可能。
    final canEdit = state.canManage(pin);
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
              onSelected: canEdit
                  ? (_) {
                      if (!selected) {
                        state.updateStatus(pin, s);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('ステータスを「${s.label}」に更新しました'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  : null,
            );
          }).toList(),
        ),
        if (!canEdit) ...[
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.lock_outline_rounded,
                  size: 14, color: Colors.black38),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'ステータスの変更・削除は、この投稿をした端末または管理者のみ行えます。',
                  style: TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 住民が押せる信頼度シグナルのボタン群。
/// 現地確認済 / 役に立った / 古い情報 をトグルする。
class _ReactionBar extends StatelessWidget {
  final Pin pin;
  const _ReactionBar({required this.pin});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ReactionChip(
          icon: Icons.visibility_rounded,
          label: '現地確認済',
          count: pin.confirmedBy.length,
          active: state.hasConfirmed(pin),
          color: const Color(0xFFFB8C00),
          onTap: () => state.toggleConfirm(pin),
        ),
        _ReactionChip(
          icon: Icons.thumb_up_alt_rounded,
          label: '役に立った',
          count: pin.helpfulBy.length,
          active: state.hasHelpful(pin),
          color: const Color(0xFF2E7D32),
          onTap: () => state.toggleHelpful(pin),
        ),
        _ReactionChip(
          icon: Icons.history_toggle_off_rounded,
          label: '古い情報',
          count: pin.outdatedBy.length,
          active: state.hasOutdated(pin),
          color: const Color(0xFF8D6E63),
          onTap: () => state.toggleOutdated(pin),
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.14) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.7)
                : Colors.black.withValues(alpha: 0.12),
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: active ? color : Colors.black45),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? color : Colors.black54,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? color : Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
