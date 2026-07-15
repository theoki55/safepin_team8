import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'models/attachment.dart';
import 'models/enums.dart';
import 'models/pin.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'services/hive_pin_repository.dart';
import 'services/settings_service.dart';
import 'theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final repository = HivePinRepository();
  final settings = SettingsService();

  final appState = AppState(repository: repository, settings: settings);
  await appState.init();

  // 初回起動時のみサンプルデータを投入(デモ用)
  if (appState.allPins.isEmpty) {
    await _seedSampleData(appState);
  }

  runApp(CrisisCompassApp(appState: appState));
}

class CrisisCompassApp extends StatelessWidget {
  final AppState appState;
  const CrisisCompassApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomeScreen(),
      ),
    );
  }
}

/// デモ用サンプルデータ(東京駅周辺)。実データが1件でもあれば投入しない。
Future<void> _seedSampleData(AppState state) async {
  const uuid = Uuid();
  final now = DateTime.now();

  List<Attachment> none() => const <Attachment>[];

  final samples = <Pin>[
    Pin(
      id: uuid.v4(),
      type: PinType.need,
      status: PinStatus.unconfirmed,
      priority: PinPriority.high,
      title: '飲料水が不足しています',
      comment: '高齢の母と2人暮らし。備蓄の水が残りわずかです。2Lペットボトルを分けていただけると助かります。',
      lat: 35.6820,
      lng: 139.7660,
      authorName: '丸の内マンション 佐藤',
      mode: AppMode.disaster,
      attachments: none(),
      createdAt: now.subtract(const Duration(minutes: 12)),
      updatedAt: now.subtract(const Duration(minutes: 12)),
    ),
    Pin(
      id: uuid.v4(),
      type: PinType.need,
      status: PinStatus.confirmed,
      priority: PinPriority.medium,
      title: 'スマホの充電をしたい',
      comment: '停電で家族の安否連絡ができません。モバイルバッテリーか充電できる場所を探しています。',
      lat: 35.6795,
      lng: 139.7685,
      authorName: '匿名',
      mode: AppMode.disaster,
      attachments: none(),
      createdAt: now.subtract(const Duration(minutes: 40)),
      updatedAt: now.subtract(const Duration(minutes: 20)),
    ),
    Pin(
      id: uuid.v4(),
      type: PinType.offer,
      status: PinStatus.unconfirmed,
      priority: PinPriority.low,
      title: 'モバイルバッテリー貸せます',
      comment: '大容量バッテリーが3台あります。日中、自宅前でスマホ充電できます。声をかけてください。',
      lat: 35.6838,
      lng: 139.7642,
      authorName: '八重洲 田中',
      mode: AppMode.disaster,
      attachments: none(),
      createdAt: now.subtract(const Duration(hours: 1)),
      updatedAt: now.subtract(const Duration(hours: 1)),
    ),
    Pin(
      id: uuid.v4(),
      type: PinType.offer,
      status: PinStatus.coordinating,
      priority: PinPriority.medium,
      title: '車で物資運搬を手伝えます',
      comment: '軽トラックがあります。ガソリンは半分ほど。近隣への物資運搬をお手伝いできます。',
      lat: 35.6760,
      lng: 139.7700,
      authorName: '京橋 自主防災会',
      mode: AppMode.disaster,
      attachments: none(),
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(minutes: 30)),
    ),
    Pin(
      id: uuid.v4(),
      type: PinType.info,
      status: PinStatus.confirmed,
      priority: PinPriority.low,
      title: '〇〇公園で給水中',
      comment: '午前9時〜午後5時、給水車が来ています。容器を持参してください。',
      lat: 35.6805,
      lng: 139.7620,
      authorName: '地域包括支援センター',
      mode: AppMode.disaster,
      attachments: none(),
      createdAt: now.subtract(const Duration(hours: 3)),
      updatedAt: now.subtract(const Duration(hours: 1)),
    ),
    Pin(
      id: uuid.v4(),
      type: PinType.info,
      status: PinStatus.resolved,
      priority: PinPriority.low,
      title: '△△通りは通行止め',
      comment: '建物の外壁落下のおそれあり。復旧until未定。迂回してください。',
      lat: 35.6850,
      lng: 139.7690,
      authorName: '消防団 第3分団',
      mode: AppMode.disaster,
      attachments: none(),
      createdAt: now.subtract(const Duration(hours: 5)),
      updatedAt: now.subtract(const Duration(hours: 2)),
    ),
  ];

  for (final p in samples) {
    await state.addPin(p);
  }
}
