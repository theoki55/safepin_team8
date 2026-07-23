import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_pin_repository.dart';
import 'services/firestore_resource_repository.dart';
import 'services/settings_service.dart';
import 'theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase 初期化(Web優先。マルチプラットフォーム対応)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 一般住民向けの簡易認証(匿名認証)。
    // 起動時に端末ごとの匿名IDを自動発行する(ユーザー入力なし)。
    final authService = AuthService();
    await authService.ensureSignedIn();

    // Firestore + Storage によるクラウド保存(リアルタイム同期)
    final repository = FirestorePinRepository();
    final settings = SettingsService();

    // 地域資源(RESOURCE)の Firestore リポジトリ(`resources` コレクション)。
    final resourceRepository = FirestoreResourceRepository();

    final appState = AppState(
      repository: repository,
      settings: settings,
      auth: authService,
      resourceRepository: resourceRepository,
    );
    await appState.init();

    if (kDebugMode) {
      debugPrint('SafePin started. realtime=${appState.realtime}, '
          'pins=${appState.allPins.length}');
    }

    // デモデータは Admin SDK で Firestore に直接投入するため、
    // ローカルでのシード処理は行わない。

    runApp(SafePinApp(appState: appState));
  } catch (e, st) {
    // 初期化に失敗しても真っ白画面にせず、原因と再試行手段を表示する。
    if (kDebugMode) {
      debugPrint('SafePin init failed: $e\n$st');
    }
    runApp(SafePinErrorApp(message: e.toString()));
  }
}

/// 初期化失敗時のフォールバック画面。
/// (Firebase/Firestore の初期化に失敗した場合でも白画面を避ける)
class SafePinErrorApp extends StatelessWidget {
  final String message;
  const SafePinErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    '接続の初期化に失敗しました',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ブラウザの設定でデータ保存(IndexedDB/Cookie)が\n'
                    'ブロックされている可能性があります。\n'
                    'ページを再読み込みするか、通常モードでお試しください。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SafePinApp extends StatelessWidget {
  final AppState appState;
  const SafePinApp({super.key, required this.appState});

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
