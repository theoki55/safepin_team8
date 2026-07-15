import 'package:flutter/material.dart';

/// ピンの種別: NEED(必要な支援) / OFFER(提供できる支援) / INFO(地域情報)
enum PinType {
  need,
  offer,
  info;

  String get label {
    switch (this) {
      case PinType.need:
        return 'NEED（助けて）';
      case PinType.offer:
        return 'OFFER（手伝える）';
      case PinType.info:
        return 'INFO（地域情報）';
    }
  }

  String get shortLabel {
    switch (this) {
      case PinType.need:
        return 'NEED';
      case PinType.offer:
        return 'OFFER';
      case PinType.info:
        return 'INFO';
    }
  }

  String get description {
    switch (this) {
      case PinType.need:
        return 'SOS・安否・不足物資など、必要な支援を投稿';
      case PinType.offer:
        return '提供できる物資・スキル・人手を投稿';
      case PinType.info:
        return '給水所・通行止め・炊き出しなど地域情報を共有';
    }
  }

  Color get color {
    switch (this) {
      case PinType.need:
        return const Color(0xFFE53935); // 赤
      case PinType.offer:
        return const Color(0xFF1E88E5); // 青
      case PinType.info:
        return const Color(0xFF43A047); // 緑
    }
  }

  IconData get icon {
    switch (this) {
      case PinType.need:
        return Icons.sos_rounded;
      case PinType.offer:
        return Icons.volunteer_activism_rounded;
      case PinType.info:
        return Icons.info_rounded;
    }
  }

  static PinType fromName(String name) =>
      PinType.values.firstWhere((e) => e.name == name, orElse: () => PinType.info);
}

/// 対応ステータス: 未確認→現地確認済→支援調整中→対応済
enum PinStatus {
  unconfirmed,
  confirmed,
  coordinating,
  resolved;

  String get label {
    switch (this) {
      case PinStatus.unconfirmed:
        return '未確認';
      case PinStatus.confirmed:
        return '現地確認済';
      case PinStatus.coordinating:
        return '支援調整中';
      case PinStatus.resolved:
        return '対応済';
    }
  }

  Color get color {
    switch (this) {
      case PinStatus.unconfirmed:
        return const Color(0xFF9E9E9E); // グレー
      case PinStatus.confirmed:
        return const Color(0xFFFB8C00); // オレンジ
      case PinStatus.coordinating:
        return const Color(0xFF3949AB); // インディゴ
      case PinStatus.resolved:
        return const Color(0xFF2E7D32); // 濃い緑
    }
  }

  IconData get icon {
    switch (this) {
      case PinStatus.unconfirmed:
        return Icons.help_outline_rounded;
      case PinStatus.confirmed:
        return Icons.visibility_rounded;
      case PinStatus.coordinating:
        return Icons.handshake_rounded;
      case PinStatus.resolved:
        return Icons.check_circle_rounded;
    }
  }

  int get step {
    switch (this) {
      case PinStatus.unconfirmed:
        return 0;
      case PinStatus.confirmed:
        return 1;
      case PinStatus.coordinating:
        return 2;
      case PinStatus.resolved:
        return 3;
    }
  }

  static PinStatus fromName(String name) => PinStatus.values
      .firstWhere((e) => e.name == name, orElse: () => PinStatus.unconfirmed);
}

/// 緊急度(トリアージ): 高/中/低
enum PinPriority {
  high,
  medium,
  low;

  String get label {
    switch (this) {
      case PinPriority.high:
        return '緊急度：高';
      case PinPriority.medium:
        return '緊急度：中';
      case PinPriority.low:
        return '緊急度：低';
    }
  }

  String get shortLabel {
    switch (this) {
      case PinPriority.high:
        return '高';
      case PinPriority.medium:
        return '中';
      case PinPriority.low:
        return '低';
    }
  }

  Color get color {
    switch (this) {
      case PinPriority.high:
        return const Color(0xFFD32F2F);
      case PinPriority.medium:
        return const Color(0xFFF9A825);
      case PinPriority.low:
        return const Color(0xFF7CB342);
    }
  }

  static PinPriority fromName(String name) => PinPriority.values
      .firstWhere((e) => e.name == name, orElse: () => PinPriority.medium);
}

/// アプリのモード: 平時 / 災害
enum AppMode {
  normal,
  disaster;

  String get label {
    switch (this) {
      case AppMode.normal:
        return '平時モード';
      case AppMode.disaster:
        return '災害モード';
    }
  }

  static AppMode fromName(String name) =>
      AppMode.values.firstWhere((e) => e.name == name, orElse: () => AppMode.normal);
}
