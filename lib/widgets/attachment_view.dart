import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/attachment.dart';
import '../services/attachment_service.dart';

/// 添付画像の base64 バイト列を取得(ローカル版)。
Uint8List? _imageBytes(Attachment a) {
  final bytes = AttachmentBytes.decode(a);
  return bytes == null ? null : Uint8List.fromList(bytes);
}

/// 添付画像を表示するウィジェット。
///
/// - Firebase 版: [Attachment.url] を [Image.network] で表示
/// - ローカル版: base64 [Attachment.dataUrl] を [Image.memory] で表示
///
/// どちらのソースも無い場合は [placeholder] を返す。
class AttachmentImage extends StatelessWidget {
  final Attachment attachment;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function()? placeholderBuilder;

  const AttachmentImage({
    super.key,
    required this.attachment,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
  });

  /// 画像として表示可能なソースを持っているか。
  static bool canDisplay(Attachment a) {
    if (!a.isImage) return false;
    if (a.dataUrl != null && AttachmentBytes.decode(a) != null) return true;
    if (a.url != null && a.url!.isNotEmpty) return true;
    return false;
  }

  Widget _defaultPlaceholder() =>
      placeholderBuilder?.call() ??
      Container(
        width: width,
        height: height,
        color: Colors.black12,
        child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
      );

  Widget _loading() => Container(
        width: width,
        height: height,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // 1) ローカル base64 を優先
    final bytes = _imageBytes(attachment);
    if (bytes != null) {
      return Image.memory(bytes, width: width, height: height, fit: fit);
    }
    // 2) Firebase のダウンロードURL
    final url = attachment.url;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _loading();
        },
        errorBuilder: (context, error, stack) => _defaultPlaceholder(),
      );
    }
    // 3) どちらも無い
    return _defaultPlaceholder();
  }
}

/// 添付一覧を表示するグリッド(閲覧用)。
class AttachmentGallery extends StatelessWidget {
  final List<Attachment> attachments;
  const AttachmentGallery({super.key, required this.attachments});

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final images = attachments.where((a) => a.isImage).toList();
    final files = attachments.where((a) => !a.isImage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: images.map((a) {
              final displayable = AttachmentImage.canDisplay(a);
              return GestureDetector(
                onTap: displayable ? () => _showImageDialog(context, a) : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AttachmentImage(
                    attachment: a,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    placeholderBuilder: _placeholder,
                  ),
                ),
              );
            }).toList(),
          ),
        if (files.isNotEmpty) ...[
          if (images.isNotEmpty) const SizedBox(height: 8),
          ...files.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _FileTile(attachment: a),
              )),
        ],
      ],
    );
  }

  Widget _placeholder() => Container(
        width: 96,
        height: 96,
        color: Colors.black12,
        child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
      );

  void _showImageDialog(BuildContext context, Attachment a) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: AttachmentImage(attachment: a, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Text(
                a.name,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final Attachment attachment;
  const _FileTile({required this.attachment});

  IconData get _icon {
    final m = attachment.mimeType;
    if (m.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (m.contains('word') || m.contains('msword')) {
      return Icons.description_rounded;
    }
    if (m.contains('sheet') || m.contains('excel')) {
      return Icons.table_chart_rounded;
    }
    if (m.startsWith('video/')) return Icons.movie_rounded;
    if (m.startsWith('audio/')) return Icons.audiotrack_rounded;
    if (m.contains('zip')) return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                if (attachment.readableSize.isNotEmpty)
                  Text(
                    attachment.readableSize,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 11.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 投稿フォーム用: 添付編集グリッド(削除ボタン付き)。
class EditableAttachmentGrid extends StatelessWidget {
  final List<Attachment> attachments;
  final void Function(Attachment) onRemove;
  const EditableAttachmentGrid({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((a) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: a.isImage
                  ? _thumb(a)
                  : Container(
                      width: 84,
                      height: 84,
                      color: Colors.black.withValues(alpha: 0.05),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.insert_drive_file_rounded,
                              size: 28, color: Colors.black45),
                          const SizedBox(height: 4),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: () => onRemove(a),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _thumb(Attachment a) {
    return AttachmentImage(
      attachment: a,
      width: 84,
      height: 84,
      fit: BoxFit.cover,
      placeholderBuilder: () =>
          Container(width: 84, height: 84, color: Colors.black12),
    );
  }
}
