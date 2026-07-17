import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'services/firestore_pin_repository.dart';
import 'services/settings_service.dart';
import 'theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初期化(Web優先。マルチプラットフォーム対応)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Firestore + Storage によるクラウド保存(リアルタイム同期)
  final repository = FirestorePinRepository();
  final settings = SettingsService();

  final appState = AppState(repository: repository, settings: settings);
  await appState.init();

  if (kDebugMode) {
    debugPrint('SafePin started. realtime=${appState.realtime}, '
        'pins=${appState.allPins.length}');
  }

  // デモデータは Admin SDK で Firestore に直接投入するため、
  // ローカルでのシード処理は行わない。

  runApp(SafePinApp(appState: appState));
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
