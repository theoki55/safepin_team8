import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment.dart';
import '../models/enums.dart';
import '../models/pin.dart';
import '../providers/app_state.dart';
import '../services/attachment_service.dart';
import '../services/location_service.dart';
import '../utils/format.dart';
import '../widgets/attachment_view.dart';
import 'location_picker_screen.dart';

/// 新規ピン投稿フォーム。
/// [initialLocation] が指定されていれば、その位置を初期値にする(地図タップ経由)。
class PostPinScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final PinType? initialType;
  const PostPinScreen({super.key, this.initialLocation, this.initialType});

  @override
  State<PostPinScreen> createState() => _PostPinScreenState();
}

class _PostPinScreenState extends State<PostPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();

  final _attachmentService = AttachmentService();
  final _locationService = LocationService();

  PinType _type = PinType.need;
  PinPriority _priority = PinPriority.medium;
  LatLng? _location;
  final List<Attachment> _attachments = [];

  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? PinType.need;
    _location = widget.initialLocation;
    final saved = context.read<AppState>().authorName;
    if (saved.isNotEmpty) _authorCtrl.text = saved;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _commentCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final result = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (result.success) {
      setState(() => _location = LatLng(result.lat!, result.lng!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '現在地を取得できませんでした')),
      );
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: _location),
      ),
    );
    if (picked != null) setState(() => _location = picked);
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
        const SnackBar(content: Text('位置を指定してください（現在地 or 地図で指定）')),
      );
      return;
    }
    setState(() => _saving = true);
    final state = context.read<AppState>();
    // 起動時に匿名サインインが未完了でも、投稿直前に再度確保を試みる。
    // (Web release ではプラグイン初期化が遅れることがあるため)
    await state.ensureSignedIn();
    final author =
        _authorCtrl.text.trim().isEmpty ? '匿名' : _authorCtrl.text.trim();
    await state.setAuthorName(_authorCtrl.text.trim());

    final now = DateTime.now();
    final pin = Pin(
      id: const Uuid().v4(),
      type: _type,
      status: PinStatus.unconfirmed,
      priority: _priority,
      title: _titleCtrl.text.trim(),
      comment: _commentCtrl.text.trim(),
      lat: _location!.latitude,
      lng: _location!.longitude,
      authorName: author,
      authorUid: state.currentUid,
      mode: state.mode,
      attachments: List.of(_attachments),
      createdAt: now,
      updatedAt: now,
    );
    await state.addPin(pin);
    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ピンを投稿しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ピンを立てる')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _label('種別'),
              const SizedBox(height: 8),
              _typeSelector(),
              const SizedBox(height: 20),
              _label('タイトル'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: _type == PinType.need
                      ? '例）水が不足しています'
                      : _type == PinType.offer
                          ? '例）モバイルバッテリー貸せます'
                          : '例）〇〇公園で給水中',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'タイトルを入力してください' : null,
              ),
              const SizedBox(height: 20),
              _label('コメント（詳細）'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '状況・数量・時間帯など、詳しい内容を記入してください',
                ),
              ),
              const SizedBox(height: 20),
              _label('緊急度'),
              const SizedBox(height: 8),
              _prioritySelector(),
              const SizedBox(height: 20),
              _label('位置'),
              const SizedBox(height: 8),
              _locationSection(),
              const SizedBox(height: 20),
              _label('写真・ファイル添付'),
              const SizedBox(height: 8),
              _attachmentSection(),
              const SizedBox(height: 20),
              _label('投稿者名（任意）'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _authorCtrl,
                decoration: const InputDecoration(
                  hintText: '未入力の場合は「匿名」になります',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.push_pin_rounded),
              label: Text(_saving ? '投稿中...' : 'この内容で投稿する'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      );

  Widget _typeSelector() {
    return Column(
      children: PinType.values.map((t) {
        final selected = _type == t;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _type = t),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? t.color.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? t.color : Colors.black.withValues(alpha: 0.12),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(color: t.color, shape: BoxShape.circle),
                    child: Icon(t.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(t.description,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: t.color),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _prioritySelector() {
    return Row(
      children: PinPriority.values.map((p) {
        final selected = _priority == p;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _priority = p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      selected ? p.color.withValues(alpha: 0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? p.color
                        : Colors.black.withValues(alpha: 0.12),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    p.shortLabel,
                    style: TextStyle(
                      color: selected ? p.color : Colors.black54,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _locationSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          if (_location != null)
            Row(
              children: [
                const Icon(Icons.place_rounded, color: Color(0xFFE64A2E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '指定済み: ${formatLatLng(_location!.latitude, _location!.longitude)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            )
          else
            Row(
              children: const [
                Icon(Icons.location_off_rounded, color: Colors.black38),
                SizedBox(width: 8),
                Expanded(
                  child: Text('位置が未指定です',
                      style: TextStyle(color: Colors.black54, fontSize: 13)),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('現在地'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickOnMap,
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('地図で指定'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _attachButton(Icons.photo_camera_rounded, 'カメラ',
                () => _addImage(true)),
            _attachButton(Icons.photo_library_rounded, '写真', () => _addImage(false)),
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
