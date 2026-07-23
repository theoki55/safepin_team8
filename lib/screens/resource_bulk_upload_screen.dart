import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/resource_category.dart';
import '../providers/app_state.dart';
import '../services/resource_csv_service.dart';

/// 管理者(自治会役員)向けの「地域資源 CSV 一括アップロード」画面。
///
/// フロー:
///  1. フォーマット案内 + テンプレートコピー
///  2. CSV ファイルを選択
///  3. 行ごとの検証結果をプレビュー(正常/注意/エラーを色分け)
///  4. 登録可能行(正常+注意)をまとめて Firestore へバッチ登録
class ResourceBulkUploadScreen extends StatefulWidget {
  const ResourceBulkUploadScreen({super.key});

  @override
  State<ResourceBulkUploadScreen> createState() =>
      _ResourceBulkUploadScreenState();
}

class _ResourceBulkUploadScreenState extends State<ResourceBulkUploadScreen> {
  final _service = ResourceCsvService();

  ResourceImportResult? _result;
  String? _fileName;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地域資源 CSV一括アップロード'),
        backgroundColor: ResourceCategory.themeColor,
        foregroundColor: Colors.white,
        // グローバルの AppBarTheme が titleTextStyle/iconTheme を濃色に固定して
        // いるため、紫背景で埋もれないようこの画面だけ白に上書きする。
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: SafeArea(
        child: _result == null ? _buildIntro(context) : _buildPreview(context),
      ),
    );
  }

  // ---------------- 導入(案内 + ファイル選択) ----------------
  Widget _buildIntro(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: ResourceCategory.themeColor.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.upload_file_rounded,
                          color: ResourceCategory.themeColor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CSVファイルで地域資源をまとめて登録します',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1行目はヘッダ行にしてください。列の順序は自由ですが、'
                    '次の列名を使用します。',
                    style: TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('列の説明',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          ...ResourceCsvService.columnHelp.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(e.key,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.value,
                        style: const TextStyle(fontSize: 11.5, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _copyTemplate,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('CSVテンプレートをコピー'),
          ),
          const SizedBox(height: 8),
          Text(
            'コピーしたテンプレートを表計算ソフト等に貼り付けて編集し、'
            'CSV形式で保存してからアップロードしてください。',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _pickAndParse,
              style: FilledButton.styleFrom(
                backgroundColor: ResourceCategory.themeColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.file_open_rounded),
              label: Text(_busy ? '読み込み中...' : 'CSVファイルを選択'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- プレビュー ----------------
  Widget _buildPreview(BuildContext context) {
    final result = _result!;
    return Column(
      children: [
        // サマリー
        Container(
          width: double.infinity,
          color: ResourceCategory.themeColor.withValues(alpha: 0.06),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fileName ?? 'CSV',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _reset,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('選び直す'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _summaryChip('読込 ${result.total}', Colors.blueGrey),
                  _summaryChip('登録可 ${result.okCount}', Colors.green),
                  if (result.warningCount > 0)
                    _summaryChip('注意 ${result.warningCount}', Colors.orange),
                  if (result.errorCount > 0)
                    _summaryChip('エラー ${result.errorCount}', Colors.red),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 行リスト
        Expanded(
          child: result.rows.isEmpty
              ? const Center(child: Text('有効なデータ行がありません'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: result.rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _rowTile(result.rows[i]),
                ),
        ),
        // 実行バー
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (result.errorCount > 0)
                  Expanded(
                    child: Text(
                      'エラー ${result.errorCount} 件は登録されません',
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.red.shade700),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed:
                      (_busy || result.importable.isEmpty) ? null : _commit,
                  style: FilledButton.styleFrom(
                    backgroundColor: ResourceCategory.themeColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text('${result.importable.length}件を登録'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _rowTile(ResourceRow row) {
    final Color statusColor;
    final IconData statusIcon;
    if (row.isError) {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline_rounded;
    } else if (row.isWarning) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline_rounded;
    }

    final r = row.resource;
    return ListTile(
      dense: true,
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: statusColor, size: 22),
          Text('${row.lineNo}行',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        ],
      ),
      title: Text(
        r != null ? r.name : '(登録不可)',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          color: row.isError ? Colors.red.shade700 : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r != null)
            Text(
              '${r.category.label}  ·  ${r.lat.toStringAsFixed(5)}, '
              '${r.lng.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11.5),
            ),
          if (row.error != null)
            Text(row.error!,
                style:
                    TextStyle(fontSize: 11.5, color: Colors.red.shade700)),
          ...row.warnings.map(
            (w) => Text('⚠ $w',
                style:
                    TextStyle(fontSize: 11, color: Colors.orange.shade800)),
          ),
        ],
      ),
    );
  }

  // ---------------- アクション ----------------
  Future<void> _copyTemplate() async {
    await Clipboard.setData(ClipboardData(text: _service.sampleCsv()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSVテンプレートをコピーしました')),
    );
  }

  Future<void> _pickAndParse() async {
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();

    // セッション期限チェック
    await state.refreshAdminSession();
    if (!mounted) return;
    if (!state.isAdmin) {
      messenger.showSnackBar(const SnackBar(
          content: Text('管理者セッションが切れました。再度ログインしてください。')));
      Navigator.of(context).pop();
      return;
    }

    setState(() => _busy = true);
    try {
      FilePickerResult? picked;
      try {
        picked = await FilePicker.platform.pickFiles(
          withData: true,
          type: FileType.custom,
          allowedExtensions: const ['csv', 'txt'],
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

      // UTF-8 優先。失敗時はそのままバイト列を文字扱い(Shift_JIS 等の簡易フォールバック)。
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = String.fromCharCodes(bytes);
      }

      final result = _service.parse(
        content,
        registeredByUid: state.currentUid,
        registeredByName: state.adminName2,
      );

      if (result.hasFatal) {
        if (!mounted) return;
        await _showFatal(result);
        return;
      }

      setState(() {
        _result = result;
        _fileName = file.name;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final state = context.read<AppState>();
    final result = _result!;

    // セッション再確認
    await state.refreshAdminSession();
    if (!mounted) return;
    if (!state.isAdmin) {
      messenger.showSnackBar(const SnackBar(
          content: Text('管理者セッションが切れました。再度ログインしてください。')));
      navigator.pop();
      return;
    }

    final importable = result.importable;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('一括登録の確認'),
        content: Text(
          '${importable.length} 件の地域資源を登録します。\n'
          '${result.warningCount > 0 ? "うち ${result.warningCount} 件は注意ありです。\n" : ""}'
          '${result.errorCount > 0 ? "エラー ${result.errorCount} 件は登録されません。\n" : ""}'
          '\nよろしいですか？',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('${importable.length}件を登録')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final saved = await state.addResources(importable);
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('$saved 件の地域資源を登録しました')));
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('登録に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _fileName = null;
    });
  }

  Future<void> _showFatal(ResourceImportResult result) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('読み込めませんでした'),
        content: SingleChildScrollView(
          child: Text(
            result.fatalErrors.isEmpty
                ? '有効なデータが見つかりませんでした。'
                : result.fatalErrors.join('\n'),
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
}
