import 'package:flutter_test/flutter_test.dart';
import 'package:lunavaritia/services/lunacedia_client.dart';

void main() {
  group('eventToAlert (ADR-013 I4)', () {
    test('carries through the real read status from LunAcedia instead of always false', () {
      final alert = eventToAlert({
        'dedupeKey': 'e1',
        'type': 'email.received',
        'title': 'Test',
        'priority': 'normal',
        'ts': 1700000000000,
        'read': true,
      });

      expect(alert.read, isTrue);
    });

    test('defaults to unread when the field is absent', () {
      final alert = eventToAlert({
        'dedupeKey': 'e2',
        'type': 'email.received',
        'title': 'Test',
        'priority': 'normal',
        'ts': 1700000000000,
      });

      expect(alert.read, isFalse);
    });
  });
}
