import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/app_state.dart';

const _disasterColor = Color(0xFFD32F2F);
const _normalColor = Color(0xFF2E7D32);

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
                  // ---- 表示モード ----
                  _ModeSection(state: state),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Text('種別',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            state.applyRecommendedFilterForCurrentMode(),
                        icon: const Icon(Icons.auto_awesome, size: 15),
                        label: Text(
                          state.mode == AppMode.disaster
                              ? '災害モードの推奨に戻す'
                              : '平時モードの推奨に戻す',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
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

/// 表示モード(平時/災害)の絞り込みセクション。
class _ModeSection extends StatelessWidget {
  final AppState state;
  const _ModeSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDisaster = state.mode == AppMode.disaster;
    final modeColor = isDisaster ? _disasterColor : _normalColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('表示モード',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: modeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: modeColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isDisaster
                        ? Icons.warning_amber_rounded
                        : Icons.wb_sunny_outlined,
                    color: modeColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDisaster ? '現在: 災害モード' : '現在: 平時モード',
                    style: TextStyle(
                        color: modeColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                state.showAllModes
                    ? '平時・災害の両方のピンを表示しています'
                    : isDisaster
                        ? '災害モードで投稿されたピンのみ表示しています'
                        : '平時モードで投稿されたピンのみ表示しています',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('両モードのピンを表示',
                    style: TextStyle(fontSize: 13.5)),
                subtitle: const Text('平時・災害のピンをまとめて表示',
                    style: TextStyle(fontSize: 11.5)),
                value: state.showAllModes,
                activeThumbColor: modeColor,
                onChanged: (v) => state.setShowAllModes(v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
