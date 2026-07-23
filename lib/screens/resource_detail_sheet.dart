import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/resource.dart';
import '../providers/app_state.dart';
import '../utils/service_area.dart';
import '../widgets/attachment_view.dart';
import 'resource_form_screen.dart';

/// 地域資源(RESOURCE)の詳細を表示するボトムシート。
///
/// 設備情報(種別・名称・住所・管理団体・最終点検日・利用可否・メモ)を表示。
/// 管理者には編集・削除ボタンを出す。ステータスワークフローや通報はない。
class ResourceDetailSheet extends StatelessWidget {
  final String resourceId;
  const ResourceDetailSheet({super.key, required this.resourceId});

  static Future<void> show(BuildContext context, String resourceId) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ResourceDetailSheet(resourceId: resourceId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final matches =
            state.allResources.where((r) => r.id == resourceId).toList();
        if (matches.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('この資源は削除されました'),
          );
        }
        final r = matches.first;
        final df = DateFormat('yyyy/MM/dd');
        final inArea = ServiceArea.contains(LatLng(r.lat, r.lng));

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                // ヘッダ: カテゴリバッジ
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: r.category.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(r.category.icon,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.category.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: r.category.color)),
                          Text(r.name,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 公式情報バッジ + 利用可否
                Row(
                  children: [
                    _chip(
                      icon: Icons.verified_rounded,
                      label: '自治会登録の公式情報',
                      color: const Color(0xFF6A1B9A),
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      icon: r.available
                          ? Icons.check_circle_rounded
                          : Icons.do_not_disturb_on_rounded,
                      label: r.available ? '利用可能' : '利用不可',
                      color: r.available
                          ? const Color(0xFF2E7D32)
                          : Colors.redAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _infoRow(Icons.place_rounded, '住所',
                    r.address.isEmpty ? '（未設定）' : r.address),
                _infoRow(
                  Icons.my_location_rounded,
                  '位置',
                  '${r.lat.toStringAsFixed(6)}, ${r.lng.toStringAsFixed(6)}'
                      '${inArea ? '（対象区域内）' : '（区域外）'}',
                ),
                _infoRow(Icons.groups_rounded, '管理団体',
                    r.managedBy.isEmpty ? '（未設定）' : r.managedBy),
                _infoRow(
                  Icons.event_available_rounded,
                  '最終点検日',
                  r.lastInspected != null
                      ? df.format(r.lastInspected!)
                      : '（未設定）',
                ),
                if (r.note.isNotEmpty)
                  _infoRow(Icons.sticky_note_2_rounded, 'メモ', r.note),
                if (r.registeredByName.isNotEmpty)
                  _infoRow(Icons.person_rounded, '登録者', r.registeredByName),
                if (r.attachments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.attachment_rounded,
                          size: 18, color: Colors.black45),
                      const SizedBox(width: 10),
                      Text(
                        '添付（${r.attachments.length}件）',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AttachmentGallery(attachments: r.attachments),
                ],
                const SizedBox(height: 16),
                // 管理者操作
                if (state.isAdmin) ...[
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ResourceFormScreen(existing: r),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('編集'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDelete(context, state, r),
                          icon: const Icon(Icons.delete_rounded,
                              color: Colors.redAccent),
                          label: const Text('削除',
                              style: TextStyle(color: Colors.redAccent)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState state, Resource r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('資源を削除しますか？'),
        content: Text('「${r.name}」を地図から削除します。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await state.deleteResource(r.id);
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('資源を削除しました')),
    );
  }

  Widget _chip(
      {required IconData icon,
      required String label,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.black45),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}
