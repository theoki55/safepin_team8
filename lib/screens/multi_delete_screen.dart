import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pin.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/badges.dart';

/// 複数のピンを選択して一括削除する画面。
class MultiDeleteScreen extends StatefulWidget {
  const MultiDeleteScreen({super.key});

  @override
  State<MultiDeleteScreen> createState() => _MultiDeleteScreenState();
}

class _MultiDeleteScreenState extends State<MultiDeleteScreen> {
  final Set<String> _selected = {};
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // 全モードのピンを対象にする(削除は全件から選べるべき)
    final pins = [...state.allPins]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final allSelected = pins.isNotEmpty && _selected.length == pins.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.isEmpty ? '複数選択して削除' : '${_selected.length} 件選択中'),
        actions: [
          TextButton(
            onPressed: pins.isEmpty
                ? null
                : () {
                    setState(() {
                      if (allSelected) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(pins.map((p) => p.id));
                      }
                    });
                  },
            child: Text(allSelected ? '全解除' : '全選択'),
          ),
        ],
      ),
      body: pins.isEmpty
          ? const Center(
              child: Text('削除できるピンがありません',
                  style: TextStyle(color: Colors.black45)),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: pins.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final pin = pins[i];
                final checked = _selected.contains(pin.id);
                return CheckboxListTile(
                  value: checked,
                  onChanged: _deleting
                      ? null
                      : (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(pin.id);
                            } else {
                              _selected.remove(pin.id);
                            }
                          });
                        },
                  title: Text(
                    pin.title.isEmpty ? '(タイトルなし)' : pin.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        TypeBadge(type: pin.type, compact: true),
                        const SizedBox(width: 6),
                        StatusChip(status: pin.status, compact: true),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${pin.authorName}・${relativeTime(pin.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
      bottomNavigationBar: pins.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: (_selected.isEmpty || _deleting)
                        ? null
                        : () => _confirmDelete(context, pins),
                    icon: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(_selected.isEmpty
                        ? '削除するピンを選択'
                        : '${_selected.length} 件を削除'),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, List<Pin> pins) async {
    final count = _selected.length;
    // await をまたぐ前に context 依存の参照を取得しておく
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$count 件を削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deleting = true);
    final deleted = await state.deletePins(_selected.toList());
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _selected.clear();
    });
    messenger.showSnackBar(
      SnackBar(content: Text('$deleted 件のピンを削除しました')),
    );
    navigator.pop();
  }
}
