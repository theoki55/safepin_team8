import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/app_state.dart';
import '../utils/constants.dart';

/// 設定画面: モード切替・投稿者名・アプリ情報。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            _sectionTitle('モード'),
            const SizedBox(height: 8),
            _modeCard(context, state),
            const SizedBox(height: 24),
            _sectionTitle('投稿者名'),
            const SizedBox(height: 8),
            _authorCard(context, state),
            const SizedBox(height: 24),
            _sectionTitle('データ'),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_sweep_outlined,
                    color: Colors.redAccent),
                title: const Text('すべてのピンを削除'),
                subtitle: Text('現在 ${state.allPins.length} 件'),
                onTap: () => _confirmClear(context, state),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('このアプリについて'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppConstants.appName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(AppConstants.appTagline,
                        style:
                            TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 12),
                    const Text(
                      '住民自身が NEED（必要な支援）・OFFER（提供できる支援）・INFO（地域情報）を'
                      '地図上で共有し、地域のニーズと資源を可視化する共助型プラットフォームです。',
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'MVP版：データはこの端末内にのみ保存されます（オフライン）。'
                              '複数人でのリアルタイム共有は今後のバージョンで対応予定です。',
                              style: TextStyle(fontSize: 11.5, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54));

  Widget _modeCard(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: AppMode.values.map((m) {
            final selected = state.mode == m;
            final isDisaster = m == AppMode.disaster;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => state.setMode(m),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? (isDisaster
                            ? const Color(0xFFD32F2F).withValues(alpha: 0.1)
                            : const Color(0xFF2E7D32).withValues(alpha: 0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? (isDisaster
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFF2E7D32))
                          : Colors.black12,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDisaster
                            ? Icons.warning_amber_rounded
                            : Icons.wb_sunny_outlined,
                        color: isDisaster
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(
                              isDisaster
                                  ? 'SOS・安否・不足物資の投稿を優先。緊急時に切り替え'
                                  : '地域情報の共有・防災訓練での利用に最適',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            color: isDisaster
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF2E7D32)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _authorCard(BuildContext context, AppState state) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline_rounded),
        title: Text(state.authorName.isEmpty ? '匿名' : state.authorName),
        subtitle: const Text('投稿時のデフォルト表示名'),
        trailing: const Icon(Icons.edit_outlined, size: 18),
        onTap: () => _editAuthor(context, state),
      ),
    );
  }

  void _editAuthor(BuildContext context, AppState state) {
    final ctrl = TextEditingController(text: state.authorName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('投稿者名を設定'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '例）〇〇自治会 田中 / 匿名',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              state.setAuthorName(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('すべてのピンを削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ids = state.allPins.map((e) => e.id).toList();
              for (final id in ids) {
                await state.deletePin(id);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
