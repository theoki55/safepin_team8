import '../utils/communities.dart';
import 'attachment.dart';
import 'resource_category.dart';

/// 地域資源(RESOURCE)1件。
///
/// 街頭消火器・土のう置き場・AED・防災倉庫・井戸・給水拠点・一時集合場所など、
/// 自治会管理者が登録する「恒久的な地域設備」を表す。
///
/// NEED/OFFER/INFO の Pin とは別コレクション(`resources`)で管理し、
/// 次の点が異なる:
///  - 位置は常に正確表示(ぼかさない)。設備の在り処が分からないと無意味なため。
///  - 対応ステータスや通報のワークフローは持たない。代わりに
///    「利用可否」「最終点検日」など設備固有の属性を持つ。
///  - 登録は管理者のみ。誰が登録したかを [registeredByUid] / [registeredByName] に刻む。
class Resource {
  final String id;
  final ResourceCategory category;

  /// 表示名(例:「4丁目第1消火器」「下目黒5丁目防災倉庫」)。
  final String name;

  final double lat;
  final double lng;

  /// 補助的な住所文字列(任意)。
  final String address;

  /// 利用上の注意・開錠方法・使い方メモ(任意)。
  final String note;

  /// 管理団体(自治会名など)。
  final String managedBy;

  /// 最終点検日(消火器・AEDなどで重要)。未設定なら null。
  final DateTime? lastInspected;

  /// 現在利用可能か(点検中・撤去済などで false)。
  final bool available;

  /// 登録した管理者の匿名UID。
  final String registeredByUid;

  /// 登録した管理者名(役員名/自治会名)。監査・表示用。
  final String registeredByName;

  /// 所属コミュニティID(自治会/地域)。未設定の旧データは既定へフォールバック。
  final String communityId;

  /// 添付ファイル(設備の写真・案内図・使い方PDF など)。
  final List<Attachment> attachments;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Resource({
    required this.id,
    required this.category,
    required this.name,
    required this.lat,
    required this.lng,
    this.address = '',
    this.note = '',
    this.managedBy = '',
    this.lastInspected,
    this.available = true,
    this.registeredByUid = '',
    this.registeredByName = '',
    this.communityId = kDefaultCommunityId,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Resource copyWith({
    ResourceCategory? category,
    String? name,
    double? lat,
    double? lng,
    String? address,
    String? note,
    String? managedBy,
    DateTime? lastInspected,
    bool? available,
    String? registeredByUid,
    String? registeredByName,
    String? communityId,
    List<Attachment>? attachments,
    DateTime? updatedAt,
  }) {
    return Resource(
      id: id,
      category: category ?? this.category,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      note: note ?? this.note,
      managedBy: managedBy ?? this.managedBy,
      lastInspected: lastInspected ?? this.lastInspected,
      available: available ?? this.available,
      registeredByUid: registeredByUid ?? this.registeredByUid,
      registeredByName: registeredByName ?? this.registeredByName,
      communityId: communityId ?? this.communityId,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// ローカル(Hive)用マップ。添付は base64(dataUrl)も含めて保存。
  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category.key,
        'name': name,
        'lat': lat,
        'lng': lng,
        'address': address,
        'note': note,
        'managedBy': managedBy,
        'lastInspected': lastInspected?.toIso8601String(),
        'available': available,
        'registeredByUid': registeredByUid,
        'registeredByName': registeredByName,
        'communityId': communityId,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Firestore 用マップ。添付は base64 を保存せず Storage URL のみ保存する。
  Map<String, dynamic> toFirestoreMap() => {
        'id': id,
        'category': category.key,
        'name': name,
        'lat': lat,
        'lng': lng,
        'address': address,
        'note': note,
        'managedBy': managedBy,
        'lastInspected': lastInspected?.toIso8601String(),
        'available': available,
        'registeredByUid': registeredByUid,
        'registeredByName': registeredByName,
        'communityId': communityId,
        'attachments': attachments.map((a) => a.toFirestoreMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Resource.fromMap(Map<dynamic, dynamic> map) {
    final inspectedRaw = map['lastInspected'] as String?;
    final rawAttachments = (map['attachments'] as List?) ?? const [];
    return Resource(
      id: map['id'] as String,
      category: ResourceCategory.fromName(
          map['category'] as String? ?? 'gatheringSpot'),
      name: (map['name'] as String?) ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      address: (map['address'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      managedBy: (map['managedBy'] as String?) ?? '',
      lastInspected: (inspectedRaw != null && inspectedRaw.isNotEmpty)
          ? DateTime.tryParse(inspectedRaw)
          : null,
      available: (map['available'] as bool?) ?? true,
      registeredByUid: (map['registeredByUid'] as String?) ?? '',
      registeredByName: (map['registeredByName'] as String?) ?? '',
      communityId: (map['communityId'] as String?)?.isNotEmpty == true
          ? map['communityId'] as String
          : kDefaultCommunityId,
      attachments: rawAttachments
          .whereType<Map>()
          .map((m) => Attachment.fromMap(m))
          .toList(),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
