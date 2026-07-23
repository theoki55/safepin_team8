import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/app_state.dart';
import '../services/pin_import_service.dart';
import '../utils/constants.dart';
import 'multi_delete_screen.dart';

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
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file_rounded,
                        color: Color(0xFFE64A2E)),
                    title: const Text('一括アップロード（インポート）'),
                    subtitle: const Text('CSV / JSON ファイルからピンをまとめて登録'),
                    onTap: () => _importPins(context, state),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.download_rounded,
                        color: Colors.blueGrey),
                    title: const Text('エクスポート'),
                    subtitle: Text('現在の ${state.allPins.length} 件を CSV / JSON で出力'),
                    onTap: state.allPins.isEmpty
                        ? null
                        : () => _exportPins(context, state),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.checklist_rounded,
                        color: Colors.indigo),
                    title: const Text('複数選択して削除'),
                    subtitle: const Text('ピンを選んでまとめて削除'),
                    onTap: state.allPins.isEmpty
                        ? null
                        : () => _openMultiDelete(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined,
                        color: Colors.redAccent),
                    title: const Text('すべてのピンを削除'),
                    subtitle: Text('現在 ${state.allPins.length} 件'),
                    onTap: state.allPins.isEmpty
                        ? null
                        : () => _confirmClear(context, state),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('管理者（自治会役員）'),
            const SizedBox(height: 8),
            _adminCard(context, state),
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

  Widget _adminCard(BuildContext context, AppState state) {
    if (state.isAdmin) {
      return Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.verified_user_rounded,
                  color: Color(0xFF00897B)),
              title: const Text('管理者モード：ON',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('すべての投稿の編集・削除・非表示解除ができます'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('管理者モードを解除'),
              onTap: () async {
                await state.disableAdmin();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('管理者モードを解除しました')),
                  );
                }
              },
            ),
          ],
        ),
      );
    }
    return Card(
      child: ListTile(
        leading:
            const Icon(Icons.admin_panel_settings_outlined, color: Colors.indigo),
        title: const Text('管理者モードにする'),
        subtitle: const Text('合言葉を入力すると、投稿の管理ができるようになります'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _promptAdminPassphrase(context, state),
      ),
    );
  }

  Future<void> _promptAdminPassphrase(
      BuildContext context, AppState state) async {
    final controller = TextEditingController();
    var obscure = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('管理者の合言葉'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '自治会から共有された合言葉を入力してください。',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '合言葉',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                    onSubmitted: (_) => Navigator.pop(dialogContext, true),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('確認'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    final success = await state.tryEnableAdmin(controller.text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '管理者モードを有効にしました' : '合言葉が正しくありません'),
        backgroundColor: success ? const Color(0xFF00897B) : Colors.redAccent,
      ),
    );
  }

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
        content: Text('${state.allPins.length} 件すべてを削除します。この操作は取り消せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ids = state.allPins.map((e) => e.id).toList();
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final n = await state.deletePins(ids);
              messenger.showSnackBar(
                SnackBar(content: Text('$n 件のピンを削除しました')),
              );
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // ---------------- 一括アップロード ----------------
  Future<void> _importPins(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = PinImportService();

    // まず説明ダイアログ(フォーマット案内 + テンプレコピー)
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('一括アップロード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CSV または JSON ファイルを選択してください。',
                style: TextStyle(fontSize: 13.5)),
            const SizedBox(height: 10),
            const Text('CSV の列（1行目はヘッダ）:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 4),
            const Text(
              'type, title, comment, lat, lng, priority, status, mode, authorName\n'
              '※ lat / lng は必須。type は need/offer/info。',
              style: TextStyle(fontSize: 11.5, height: 1.5),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: service.sampleCsv()));
                  messenger.showSnackBar(const SnackBar(
                      content: Text('CSVテンプレートをコピーしました')));
                },
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('CSVテンプレートをコピー',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ファイルを選択'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    // ファイル選択
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['csv', 'json', 'txt'],
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ファイル選択エラー: $e')));
      return;
    }
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('ファイルの読み込みに失敗しました')));
      return;
    }

    String content;
    try {
      content = String.fromCharCodes(bytes);
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('ファイルの文字コードを読み取れませんでした')));
      return;
    }

    final result = service.parse(content, fileName: file.name);
    if (!result.hasPins) {
      if (!context.mounted) return;
      await _showImportError(context, result);
      return;
    }

    // 確認ダイアログ
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('インポート内容の確認'),
        content: Text(
          '読み込み: ${result.total} 件\n'
          '登録可能: ${result.pins.length} 件\n'
          '${result.skipped > 0 ? "スキップ: ${result.skipped} 件（不正データ）\n" : ""}'
          '\nこれらを現在のモード設定に関わらず登録します。よろしいですか？',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('${result.pins.length}件を登録')),
        ],
      ),
    );
    if (confirmed != true) return;

    // 登録実行(プログレス)
    if (!context.mounted) return;
    _showProgress(context, '登録中...');
    final added = await state.addPins(result.pins);
    if (context.mounted) Navigator.pop(context); // プログレス閉じる
    messenger.showSnackBar(
      SnackBar(content: Text('$added 件のピンを登録しました')),
    );
  }

  Future<void> _showImportError(
      BuildContext context, ImportResult result) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('インポートできませんでした'),
        content: SingleChildScrollView(
          child: Text(
            result.errors.isEmpty
                ? '有効なデータが見つかりませんでした。'
                : result.errors.take(10).join('\n'),
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる')),
        ],
      ),
    );
  }

  // ---------------- エクスポート ----------------
  Future<void> _exportPins(BuildContext context, AppState state) async {
    final service = PinImportService();
    final messenger = ScaffoldMessenger.of(context);
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('エクスポート形式'),
        content: const Text('形式を選択してください。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'csv'),
              child: const Text('CSV')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'json'),
              child: const Text('JSON')),
        ],
      ),
    );
    if (format == null) return;
    final pins = state.allPins;
    final text =
        format == 'csv' ? service.toCsv(pins) : service.toJson(pins);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('エクスポート (${format.toUpperCase()})'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              messenger.showSnackBar(
                  const SnackBar(content: Text('クリップボードにコピーしました')));
            },
            child: const Text('コピー'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる')),
        ],
      ),
    );
  }

  // ---------------- 複数選択削除 ----------------
  void _openMultiDelete(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MultiDeleteScreen()),
    );
  }

  void _showProgress(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
