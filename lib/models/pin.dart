import 'attachment.dart';
import 'enums.dart';

/// 地図上に立てる1件のピン(NEED/OFFER/INFO)。
class Pin {
  final String id;
  final PinType type;
  final PinStatus status;
  final PinPriority priority;

  final String title;
  final String comment;

  final double lat;
  final double lng;

  /// 投稿者名(任意入力、匿名可)
  final String authorName;

  /// 投稿者の匿名ID(Firebase Anonymous Auth の uid)。
  /// 自分の投稿だけを編集/削除できるようにするための識別子。
  /// 過去データや認証失敗時は空文字。
  final String authorUid;

  /// 平時 / 災害 どちらのモードで投稿されたか
  final AppMode mode;

  final List<Attachment> attachments;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Pin({
    required this.id,
    required this.type,
    required this.status,
    required this.priority,
    required this.title,
    required this.comment,
    required this.lat,
    required this.lng,
    required this.authorName,
    this.authorUid = '',
    required this.mode,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  Pin copyWith({
    PinType? type,
    PinStatus? status,
    PinPriority? priority,
    String? title,
    String? comment,
    double? lat,
    double? lng,
    String? authorName,
    String? authorUid,
    AppMode? mode,
    List<Attachment>? attachments,
    DateTime? updatedAt,
  }) {
    return Pin(
      id: id,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      authorName: authorName ?? this.authorName,
      authorUid: authorUid ?? this.authorUid,
      mode: mode ?? this.mode,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  bool get hasImages => attachments.any((a) => a.isImage);
  int get imageCount => attachments.where((a) => a.isImage).length;
  int get fileCount => attachments.where((a) => !a.isImage).length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'status': status.name,
        'priority': priority.name,
        'title': title,
        'comment': comment,
        'lat': lat,
        'lng': lng,
        'authorName': authorName,
        'authorUid': authorUid,
        'mode': mode.name,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Firestore 用マップ。添付は Storage URL のみ、日時は ISO 文字列で保存。
  Map<String, dynamic> toFirestoreMap() => {
        'id': id,
        'type': type.name,
        'status': status.name,
        'priority': priority.name,
        'title': title,
        'comment': comment,
        'lat': lat,
        'lng': lng,
        'authorName': authorName,
        'authorUid': authorUid,
        'mode': mode.name,
        'attachments': attachments.map((a) => a.toFirestoreMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Pin.fromMap(Map<dynamic, dynamic> map) {
    final rawAttachments = (map['attachments'] as List?) ?? const [];
    return Pin(
      id: map['id'] as String,
      type: PinType.fromName(map['type'] as String? ?? 'info'),
      status: PinStatus.fromName(map['status'] as String? ?? 'unconfirmed'),
      priority: PinPriority.fromName(map['priority'] as String? ?? 'medium'),
      title: (map['title'] as String?) ?? '',
      comment: (map['comment'] as String?) ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      authorName: (map['authorName'] as String?) ?? '匿名',
      authorUid: (map['authorUid'] as String?) ?? '',
      mode: AppMode.fromName(map['mode'] as String? ?? 'normal'),
      attachments: rawAttachments
          .whereType<Map>()
          .map((e) => Attachment.fromMap(e))
          .toList(),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
