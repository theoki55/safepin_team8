import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/app_state.dart';
import '../widgets/pin_card.dart';
import 'filter_sheet.dart';
import 'pin_detail_sheet.dart';

/// ピンの一覧画面。緊急度・新着で並び替え可能。
class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

enum _Sort { newest, priority }

class _ListScreenState extends State<ListScreen> {
  _Sort _sort = _Sort.newest;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final pins = [...state.filteredPins];
        if (_sort == _Sort.priority) {
          pins.sort((a, b) {
            final c = a.priority.index.compareTo(b.priority.index);
            if (c != 0) return c;
            return b.createdAt.compareTo(a.createdAt);
          });
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Text('${pins.length}件',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => FilterSheet.show(context),
                    icon: Icon(Icons.tune_rounded,
                        size: 16,
                        color: state.isFiltered
                            ? const Color(0xFFE64A2E)
                            : Colors.black54),
                    label: const Text('絞り込み'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_Sort>(
                    initialValue: _sort,
                    onSelected: (v) => setState(() => _sort = v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black26),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sort_rounded,
                              size: 16, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(_sort == _Sort.newest ? '新着順' : '緊急度順',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _Sort.newest, child: Text('新着順')),
                      PopupMenuItem(
                          value: _Sort.priority, child: Text('緊急度順')),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: pins.isEmpty
                  ? _empty(context, state)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90, top: 4),
                      itemCount: pins.length,
                      itemBuilder: (context, i) {
                        final pin = pins[i];
                        return PinCard(
                          pin: pin,
                          onTap: () => PinDetailSheet.show(context, pin.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context, AppState state) {
    // モード絞り込みが原因で0件の場合は、両モード表示を促す。
    final hasHiddenByMode = !state.showAllModes &&
        state.allPins.any((p) => p.mode != state.mode);
    final modeLabel = state.mode == AppMode.disaster ? '災害' : '平時';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.push_pin_outlined, size: 56, color: Colors.black26),
            const SizedBox(height: 12),
            Text('$modeLabelモードのピンはありません',
                style:
                    const TextStyle(color: Colors.black45, fontSize: 15)),
            const SizedBox(height: 4),
            if (hasHiddenByMode) ...[
              const Text('別のモードで投稿されたピンがあります',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black38, fontSize: 12.5)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => state.setShowAllModes(true),
                icon: const Icon(Icons.layers_rounded, size: 16),
                label: const Text('両モードのピンを表示'),
              ),
            ] else
              const Text('地図タブから「ピンを立てる」で投稿できます',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black38, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
