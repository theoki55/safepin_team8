import 'package:flutter_test/flutter_test.dart';
import 'package:crisis_compass/services/admin_service.dart';

void main() {
  test('hashOf is deterministic and trims input', () {
    final h1 = AdminService.hashOf('meguro2025');
    final h2 = AdminService.hashOf('  meguro2025  ');
    expect(h1, equals(h2));
    expect(h1.length, equals(64)); // SHA-256 hex
  });

  test('different inputs give different hashes', () {
    expect(AdminService.hashOf('a'), isNot(equals(AdminService.hashOf('b'))));
  });
}
