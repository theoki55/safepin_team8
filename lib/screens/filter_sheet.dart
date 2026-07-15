import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/app_state.dart';

/// 種別・ステータスで絞り込むボトムシート。
class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F5F3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Consumer<AppState>(
          builder: (context, state, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('絞り込み',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(
                        onPressed: state.isFiltered
                            ? () => state.resetFilters()
                            : null,
                        child: const Text('リセット'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('種別',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PinType.values.map((t) {
                      final on = state.typeFilter.contains(t);
                      return FilterChip(
                        label: Text(t.shortLabel),
                        avatar: Icon(t.icon,
                            size: 16, color: on ? Colors.white : t.color),
                        selected: on,
                        showCheckmark: false,
                        selectedColor: t.color,
                        backgroundColor: t.color.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: on ? Colors.white : t.color,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(color: t.color.withValues(alpha: 0.4)),
                        onSelected: (_) => state.toggleTypeFilter(t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Text('ステータス',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PinStatus.values.map((s) {
                      final on = state.statusFilter.contains(s);
                      return FilterChip(
                        label: Text(s.label),
                        avatar: Icon(s.icon,
                            size: 15, color: on ? Colors.white : s.color),
                        selected: on,
                        showCheckmark: false,
                        selectedColor: s.color,
                        backgroundColor: s.color.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: on ? Colors.white : s.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        side: BorderSide(color: s.color.withValues(alpha: 0.4)),
                        onSelected: (_) => state.toggleStatusFilter(s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('対応済みを非表示',
                        style: TextStyle(fontSize: 14)),
                    value: state.hideResolved,
                    activeThumbColor: const Color(0xFFE64A2E),
                    onChanged: (v) => state.setHideResolved(v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('閉じる'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
