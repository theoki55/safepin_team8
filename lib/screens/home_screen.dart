import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/app_state.dart';
import '../utils/constants.dart';
import 'list_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

/// アプリのメイン画面。地図/一覧/設定の3タブ。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['地図', 'ピン一覧', '設定'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final disaster = state.mode == AppMode.disaster;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _index == 0 ? AppConstants.appName : _titles[_index],
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _communityBadge(state),
              ],
            ),
            if (_index == 0)
              const Text(
                AppConstants.appTagline,
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
          ],
        ),
        actions: [
          // モード切替トグル
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => state.toggleMode(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: disaster
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      disaster
                          ? Icons.warning_amber_rounded
                          : Icons.wb_sunny_outlined,
                      color: Colors.white,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      disaster ? '災害' : '平時',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          MapScreen(),
          ListScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: '地図'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: '一覧'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '設定'),
        ],
      ),
    );
  }

  /// ヘッダに表示する現在の対象地域バッジ。タップで設定タブへ移動する。
  Widget _communityBadge(AppState state) {
    final c = state.community;
    const green = Color(0xFF2E7D32);
    return GestureDetector(
      onTap: () => setState(() => _index = 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: green.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              c.area.hasBoundaryCheck
                  ? Icons.place_rounded
                  : Icons.location_city_rounded,
              size: 12,
              color: green,
            ),
            const SizedBox(width: 3),
            Text(
              c.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
