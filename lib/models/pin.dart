import '../utils/communities.dart';
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

  /// 投稿者の匿名ID(端末ごとに発行する自前 UUID。shared_preferences に保存)。
  /// 自分の投稿だけを編集/削除できるようにするための識別子。
  /// 過去データや発行前は空文字。
  final String authorUid;

  /// 平時 / 災害 どちらのモードで投稿されたか
  final AppMode mode;

  /// 所属コミュニティID(自治会/地域)。未設定の旧データは既定へフォールバック。
  final String communityId;

  final List<Attachment> attachments;

  // ---- ステップB: コミュニティ運用フィールド ----

  /// この投稿を通報した端末UIDの一覧(重複通報防止 & 件数カウント)。
  final List<String> reportedBy;

  /// 通報が閾値に達して自動的に非表示になったか。
  final bool hiddenByReports;

  /// 「現地確認済」を押した端末UIDの一覧。
  final List<String> confirmedBy;

  /// 「役に立った」を押した端末UIDの一覧。
  final List<String> helpfulBy;

  /// 「古い情報」を押した端末UIDの一覧。
  final List<String> outdatedBy;

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
    this.communityId = kDefaultCommunityId,
    required this.attachments,
    this.reportedBy = const [],
    this.hiddenByReports = false,
    this.confirmedBy = const [],
    this.helpfulBy = const [],
    this.outdatedBy = const [],
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
    String? communityId,
    List<Attachment>? attachments,
    List<String>? reportedBy,
    bool? hiddenByReports,
    List<String>? confirmedBy,
    List<String>? helpfulBy,
    List<String>? outdatedBy,
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
      communityId: communityId ?? this.communityId,
      attachments: attachments ?? this.attachments,
      reportedBy: reportedBy ?? this.reportedBy,
      hiddenByReports: hiddenByReports ?? this.hiddenByReports,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      helpfulBy: helpfulBy ?? this.helpfulBy,
      outdatedBy: outdatedBy ?? this.outdatedBy,
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
        'communityId': communityId,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'reportedBy': reportedBy,
        'hiddenByReports': hiddenByReports,
        'confirmedBy': confirmedBy,
        'helpfulBy': helpfulBy,
        'outdatedBy': outdatedBy,
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
        'communityId': communityId,
        'attachments': attachments.map((a) => a.toFirestoreMap()).toList(),
        'reportedBy': reportedBy,
        'hiddenByReports': hiddenByReports,
        'confirmedBy': confirmedBy,
        'helpfulBy': helpfulBy,
        'outdatedBy': outdatedBy,
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
      communityId: (map['communityId'] as String?)?.isNotEmpty == true
          ? map['communityId'] as String
          : kDefaultCommunityId,
      attachments: rawAttachments
          .whereType<Map>()
          .map((e) => Attachment.fromMap(e))
          .toList(),
      reportedBy: (map['reportedBy'] as List?)?.whereType<String>().toList() ??
          const [],
      hiddenByReports: (map['hiddenByReports'] as bool?) ?? false,
      confirmedBy: (map['confirmedBy'] as List?)?.whereType<String>().toList() ??
          const [],
      helpfulBy: (map['helpfulBy'] as List?)?.whereType<String>().toList() ??
          const [],
      outdatedBy: (map['outdatedBy'] as List?)?.whereType<String>().toList() ??
          const [],
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
