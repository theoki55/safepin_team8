import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment.dart';

/// 写真・ファイルの選択を担うサービス。
///
/// Web/モバイル両対応のため、選択結果は base64 dataUrl として
/// [Attachment] に格納する(ローカル版)。
class AttachmentService {
  final _uuid = const Uuid();
  final _imagePicker = ImagePicker();

  /// 画像を1枚選択(カメラ or ギャラリー)。
  Future<Attachment?> pickImage({required bool fromCamera}) async {
    final XFile? file = await _imagePicker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 75,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final mime = _mimeFromName(file.name, fallback: 'image/jpeg');
    return Attachment(
      id: _uuid.v4(),
      kind: AttachmentKind.image,
      name: file.name,
      mimeType: mime,
      sizeBytes: bytes.length,
      dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
    );
  }

  /// 任意のファイルを複数選択。
  Future<List<Attachment>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true, // Web でも bytes を取得するため必須
    );
    if (result == null) return [];

    final attachments = <Attachment>[];
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      final mime = _mimeFromName(f.name, fallback: 'application/octet-stream');
      final isImg = mime.startsWith('image/');
      attachments.add(
        Attachment(
          id: _uuid.v4(),
          kind: isImg ? AttachmentKind.image : AttachmentKind.file,
          name: f.name,
          mimeType: mime,
          sizeBytes: bytes.length,
          dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
        ),
      );
    }
    return attachments;
  }

  String _mimeFromName(String name, {required String fallback}) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'zip':
        return 'application/zip';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return fallback;
    }
  }
}

/// 添付の base64 dataUrl からバイト列を取り出すヘルパー。
class AttachmentBytes {
  static List<int>? decode(Attachment attachment) {
    final src = attachment.dataUrl;
    if (src == null) return null;
    final idx = src.indexOf('base64,');
    if (idx < 0) return null;
    try {
      return base64Decode(src.substring(idx + 7));
    } catch (_) {
      return null;
    }
  }
}
