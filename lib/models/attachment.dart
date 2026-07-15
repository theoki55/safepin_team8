/// 添付ファイル(写真・ドキュメント等)。
///
/// MVP(ローカル版)ではファイル本体を base64 文字列(dataUrl)として保持する。
/// Firebase 移行時は本体を Storage にアップロードし、`dataUrl` を
/// ダウンロードURL(`url`)に置き換える設計とする。
enum AttachmentKind { image, file }

class Attachment {
  final String id;
  final AttachmentKind kind;
  final String name;
  final String mimeType;
  final int sizeBytes;

  /// ローカル保持用の base64 dataUrl (例: "data:image/png;base64,....")
  /// Firebase 版では null になり、代わりに [url] を使う。
  final String? dataUrl;

  /// クラウド保存時のダウンロードURL(ローカル版では null)
  final String? url;

  const Attachment({
    required this.id,
    required this.kind,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    this.dataUrl,
    this.url,
  });

  bool get isImage => kind == AttachmentKind.image;

  /// 表示に使えるソース(dataUrl 優先、なければ url)
  String? get displaySource => dataUrl ?? url;

  String get readableSize {
    if (sizeBytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    double s = sizeBytes.toDouble();
    int i = 0;
    while (s >= 1024 && i < units.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(s < 10 && i > 0 ? 1 : 0)} ${units[i]}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'dataUrl': dataUrl,
        'url': url,
      };

  factory Attachment.fromMap(Map<dynamic, dynamic> map) => Attachment(
        id: map['id'] as String,
        kind: AttachmentKind.values.firstWhere(
          (e) => e.name == map['kind'],
          orElse: () => AttachmentKind.file,
        ),
        name: (map['name'] as String?) ?? 'file',
        mimeType: (map['mimeType'] as String?) ?? 'application/octet-stream',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        dataUrl: map['dataUrl'] as String?,
        url: map['url'] as String?,
      );
}
