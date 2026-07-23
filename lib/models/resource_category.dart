import 'package:flutter/material.dart';

/// 地域資源(RESOURCE)のカテゴリ。
///
/// 街頭消火器・土のう置き場・AED など、自治会が管理する「恒久的な地域設備」を
/// 分類する。NEED/OFFER/INFO の一時的な投稿とは別系統で、平時から常設表示する。
///
/// 資源系統は既存3ピン(赤/青/緑)と色が衝突しないよう、紫〜茶系の
/// 「第4系統」の色を用いる。
enum ResourceCategory {
  fireExtinguisher, // 街頭消火器
  sandbag, // 土のう置き場
  aed, // AED
  disasterWarehouse, // 防災倉庫
  well, // 井戸
  waterSupply, // 給水拠点
  gatheringSpot; // 一時集合場所

  /// CSV や Firestore に保存する安定した文字列キー(enum名)。
  String get key => name;

  String get label {
    switch (this) {
      case ResourceCategory.fireExtinguisher:
        return '街頭消火器';
      case ResourceCategory.sandbag:
        return '土のう置き場';
      case ResourceCategory.aed:
        return 'AED';
      case ResourceCategory.disasterWarehouse:
        return '防災倉庫';
      case ResourceCategory.well:
        return '井戸';
      case ResourceCategory.waterSupply:
        return '給水拠点';
      case ResourceCategory.gatheringSpot:
        return '一時集合場所';
    }
  }

  String get description {
    switch (this) {
      case ResourceCategory.fireExtinguisher:
        return '街頭に設置された消火器の位置';
      case ResourceCategory.sandbag:
        return '浸水対策の土のう・水のうの置き場';
      case ResourceCategory.aed:
        return 'AED(自動体外式除細動器)の設置場所';
      case ResourceCategory.disasterWarehouse:
        return '防災資機材を保管する倉庫';
      case ResourceCategory.well:
        return '生活用水として使える井戸';
      case ResourceCategory.waterSupply:
        return '応急給水栓・給水拠点';
      case ResourceCategory.gatheringSpot:
        return '発災時に近隣で集まる一時集合場所';
    }
  }

  Color get color {
    switch (this) {
      case ResourceCategory.fireExtinguisher:
        return const Color(0xFF6D4C41); // ブラウン
      case ResourceCategory.sandbag:
        return const Color(0xFF8D6E63); // ライトブラウン
      case ResourceCategory.aed:
        return const Color(0xFF8E24AA); // パープル
      case ResourceCategory.disasterWarehouse:
        return const Color(0xFF5E35B1); // ディープパープル
      case ResourceCategory.well:
        return const Color(0xFF00838F); // シアン(井戸=水)
      case ResourceCategory.waterSupply:
        return const Color(0xFF0277BD); // ブルーグレー水色
      case ResourceCategory.gatheringSpot:
        return const Color(0xFF546E7A); // ブルーグレー
    }
  }

  IconData get icon {
    switch (this) {
      case ResourceCategory.fireExtinguisher:
        return Icons.fire_extinguisher_rounded;
      case ResourceCategory.sandbag:
        return Icons.dry_cleaning_rounded; // 代替(積み袋のイメージ)
      case ResourceCategory.aed:
        return Icons.monitor_heart_rounded;
      case ResourceCategory.disasterWarehouse:
        return Icons.warehouse_rounded;
      case ResourceCategory.well:
        return Icons.water_drop_rounded;
      case ResourceCategory.waterSupply:
        return Icons.water_rounded;
      case ResourceCategory.gatheringSpot:
        return Icons.groups_rounded;
    }
  }

  /// 資源系統を代表する色(凡例やフィルタボタンで使う)。
  static const Color themeColor = Color(0xFF6A1B9A);

  static ResourceCategory fromName(String name) => ResourceCategory.values
      .firstWhere((e) => e.name == name, orElse: () => ResourceCategory.gatheringSpot);

  /// キーが有効なカテゴリか(CSV バリデーション用)。
  static bool isValidKey(String key) =>
      ResourceCategory.values.any((e) => e.name == key.trim());

  /// キーからカテゴリを返す。不明なら null(CSV バリデーション用)。
  static ResourceCategory? tryFromKey(String key) {
    final k = key.trim();
    for (final c in ResourceCategory.values) {
      if (c.name == k) return c;
    }
    return null;
  }

  /// 日本語ラベルからカテゴリを返す。不明なら null(CSV バリデーション用)。
  ///
  /// 自治会の担当者が「消火器」「土のう」等の略称で入力しても拾えるよう、
  /// 正式ラベルの一致に加えて代表的な別名も許容する。
  static ResourceCategory? tryFromLabel(String label) {
    final l = label.trim();
    if (l.isEmpty) return null;
    // 正式ラベル一致
    for (final c in ResourceCategory.values) {
      if (c.label == l) return c;
    }
    // 代表的な別名
    const aliases = <String, ResourceCategory>{
      '消火器': ResourceCategory.fireExtinguisher,
      '街頭消火器': ResourceCategory.fireExtinguisher,
      '土のう': ResourceCategory.sandbag,
      '土嚢': ResourceCategory.sandbag,
      '土のう置場': ResourceCategory.sandbag,
      '水のう': ResourceCategory.sandbag,
      'ａｅｄ': ResourceCategory.aed,
      '自動体外式除細動器': ResourceCategory.aed,
      '防災倉庫': ResourceCategory.disasterWarehouse,
      '倉庫': ResourceCategory.disasterWarehouse,
      '備蓄倉庫': ResourceCategory.disasterWarehouse,
      '井戸': ResourceCategory.well,
      '給水': ResourceCategory.waterSupply,
      '給水所': ResourceCategory.waterSupply,
      '給水栓': ResourceCategory.waterSupply,
      '集合場所': ResourceCategory.gatheringSpot,
      '一時集合場所': ResourceCategory.gatheringSpot,
      '集合': ResourceCategory.gatheringSpot,
    };
    final byAlias = aliases[l];
    if (byAlias != null) return byAlias;
    // 大文字小文字を無視した英字キー(AED 等)
    final lower = l.toLowerCase();
    if (lower == 'aed') return ResourceCategory.aed;
    return null;
  }

  /// キー(英字)または日本語ラベルからカテゴリを解決する。不明なら null。
  static ResourceCategory? resolve(String input) {
    return tryFromKey(input) ?? tryFromLabel(input);
  }
}
