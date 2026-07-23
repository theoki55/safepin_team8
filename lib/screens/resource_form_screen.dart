import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment.dart';
import '../models/resource.dart';
import '../models/resource_category.dart';
import '../providers/app_state.dart';
import '../services/attachment_service.dart';
import '../utils/service_area.dart';
import '../widgets/attachment_view.dart';
import 'location_picker_screen.dart';

/// 管理者(自治会役員)向けの「地域資源を1件登録/編集」フォーム。
///
/// 消火器・土のう置き場・AED などの恒久的な設備を、正確な位置で登録する。
/// 一般利用者には表示しない(呼び出し側で isAdmin をチェックする)。
class ResourceFormScreen extends StatefulWidget {
  /// 編集対象。null なら新規登録。
  final Resource? existing;
  const ResourceFormScreen({super.key, this.existing});

  @override
  State<ResourceFormScreen> createState() => _ResourceFormScreenState();
}

class _ResourceFormScreenState extends State<ResourceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late ResourceCategory _category;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _managedByController = TextEditingController();
  LatLng? _location;
  DateTime? _lastInspected;
  bool _available = true;
  bool _saving = false;

  final _attachmentService = AttachmentService();
  final List<Attachment> _attachments = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? ResourceCategory.fireExtinguisher;
    if (e != null) {
      _nameController.text = e.name;
      _addressController.text = e.address;
      _noteController.text = e.note;
      _managedByController.text = e.managedBy;
      _location = LatLng(e.lat, e.lng);
      _lastInspected = e.lastInspected;
      _available = e.available;
      _attachments.addAll(e.attachments);
    } else {
      // 新規時は管理者名を管理団体の初期値に流用
      final state = context.read<AppState>();
      _managedByController.text = state.adminName2;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _managedByController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: _location),
      ),
    );
    if (picked != null) {
      setState(() => _location = picked);
    }
  }

  Future<void> _pickInspectionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastInspected ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      helpText: '最終点検日を選択',
    );
    if (picked != null) {
      setState(() => _lastInspected = picked);
    }
  }

  Future<void> _addImage(bool fromCamera) async {
    try {
      final a = await _attachmentService.pickImage(fromCamera: fromCamera);
      if (a != null) setState(() => _attachments.add(a));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像を追加できませんでした（$e）')),
        );
      }
    }
  }

  Future<void> _addFiles() async {
    try {
      final list = await _attachmentService.pickFiles();
      if (list.isNotEmpty) setState(() => _attachments.addAll(list));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイルを追加できませんでした（$e）')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('位置を指定してください')),
      );
      return;
    }
    // 区域外は警告のみ(登録は許可)
    if (!ServiceArea.contains(_location!)) {
      final proceed = await _confirmOutOfArea();
      if (proceed != true) return;
      if (!mounted) return;
    }

    setState(() => _saving = true);
    final state = context.read<AppState>();
    final now = DateTime.now();
    try {
      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          category: _category,
          name: _nameController.text.trim(),
          lat: _location!.latitude,
          lng: _location!.longitude,
          address: _addressController.text.trim(),
          note: _noteController.text.trim(),
          managedBy: _managedByController.text.trim(),
          lastInspected: _lastInspected,
          available: _available,
          attachments: List.of(_attachments),
          updatedAt: now,
        );
        await state.updateResource(updated);
      } else {
        final resource = Resource(
          id: const Uuid().v4(),
          category: _category,
          name: _nameController.text.trim(),
          lat: _location!.latitude,
          lng: _location!.longitude,
          address: _addressController.text.trim(),
          note: _noteController.text.trim(),
          managedBy: _managedByController.text.trim(),
          lastInspected: _lastInspected,
          available: _available,
          registeredByUid: state.currentUid,
          registeredByName: state.adminName2,
          attachments: List.of(_attachments),
          createdAt: now,
          updatedAt: now,
        );
        await state.addResource(resource);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? '資源を更新しました' : '資源を登録しました'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<bool?> _confirmOutOfArea() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('対象区域の外です'),
        content: Text(
          '選択した位置は${ServiceArea.areaLabel}の外です。'
          'このまま登録してもよろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('位置を選び直す'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('このまま登録する'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd');
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '資源を編集' : '地域資源を登録'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _adminBadge(context),
              const SizedBox(height: 16),
              _categorySection(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名称 *',
                  hintText: '例：4丁目第1消火器',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '名称を入力してください' : null,
              ),
              const SizedBox(height: 16),
              _locationSection(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '住所(任意)',
                  hintText: '例：目黒区下目黒4-1 電柱脇',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _managedByController,
                decoration: const InputDecoration(
                  labelText: '管理団体(任意)',
                  hintText: '例：下目黒4丁目自治会',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // 最終点検日
              InkWell(
                onTap: _pickInspectionDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '最終点検日(任意)',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(
                    _lastInspected != null
                        ? df.format(_lastInspected!)
                        : '未設定',
                    style: TextStyle(
                      color: _lastInspected != null
                          ? null
                          : Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _available,
                onChanged: (v) => setState(() => _available = v),
                title: const Text('現在利用可能'),
                subtitle: const Text('点検中・撤去済などの場合はオフ'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '使い方・注意メモ(任意)',
                  hintText: '例：夜間は施錠。鍵は町会長宅。',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              _attachmentSection(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isEdit ? '更新する' : '登録する'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: ResourceCategory.themeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminBadge(BuildContext context) {
    final name = context.read<AppState>().adminName2;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ResourceCategory.themeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ResourceCategory.themeColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded,
              size: 18, color: ResourceCategory.themeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name.isEmpty
                  ? '管理者として登録します(公式情報として表示されます)'
                  : '登録者：$name',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('種別 *',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ResourceCategory.values.map((c) {
            final selected = c == _category;
            return ChoiceChip(
              avatar: Icon(
                c.icon,
                size: 18,
                color: selected ? Colors.white : c.color,
              ),
              label: Text(c.label),
              selected: selected,
              selectedColor: c.color,
              labelStyle: TextStyle(
                color: selected ? Colors.white : null,
                fontSize: 13,
              ),
              onSelected: (_) => setState(() => _category = c),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _locationSection() {
    final inArea = _location != null && ServiceArea.contains(_location!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('位置 *',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickLocation,
          icon: const Icon(Icons.map_rounded),
          label: Text(_location == null ? '地図で指定' : '位置を選び直す'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
          ),
        ),
        if (_location != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: inArea
                  ? const Color(0xFF2E7D32).withValues(alpha: 0.08)
                  : const Color(0xFFFF6D00).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  inArea ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  size: 18,
                  color: inArea
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFFF6D00),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inArea
                        ? '${ServiceArea.areaNameOf(_location!) ?? ServiceArea.areaLabel}(対象区域内)'
                        : '${ServiceArea.areaLabel}の外です',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '緯度 ${_location!.latitude.toStringAsFixed(6)} / '
            '経度 ${_location!.longitude.toStringAsFixed(6)}',
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
          ),
        ],
      ],
    );
  }

  Widget _attachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('写真・ファイル添付(任意)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _attachButton(
                Icons.photo_camera_rounded, 'カメラ', () => _addImage(true)),
            _attachButton(
                Icons.photo_library_rounded, '写真', () => _addImage(false)),
            _attachButton(Icons.attach_file_rounded, 'ファイル', _addFiles),
          ],
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          EditableAttachmentGrid(
            attachments: _attachments,
            onRemove: (a) => setState(() => _attachments.remove(a)),
          ),
        ],
      ],
    );
  }

  Widget _attachButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
