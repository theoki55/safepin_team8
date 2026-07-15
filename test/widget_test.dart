// 基本的なスモークテスト。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('ピン立てマップ'))),
      ),
    );
    expect(find.text('ピン立てマップ'), findsOneWidget);
  });
}
