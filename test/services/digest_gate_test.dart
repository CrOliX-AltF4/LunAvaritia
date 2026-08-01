import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/services/digest_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DigestGate', () {
    test('shouldShow returns true when never shown before', () async {
      SharedPreferences.setMockInitialValues({});
      const gate = DigestGate();

      expect(await gate.shouldShow(), isTrue);
    });

    test('shouldShow returns false right after markShown', () async {
      SharedPreferences.setMockInitialValues({});
      const gate = DigestGate();

      await gate.markShown();

      expect(await gate.shouldShow(), isFalse);
    });

    test('shouldShow returns true once minGap has elapsed since the stored timestamp', () async {
      final staleTs = DateTime.now().subtract(const Duration(hours: 5)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({'digest_last_shown_at': staleTs});
      const gate = DigestGate(minGap: Duration(hours: 4));

      expect(await gate.shouldShow(), isTrue);
    });

    test('shouldShow returns false when the gap has not elapsed yet', () async {
      final recentTs = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({'digest_last_shown_at': recentTs});
      const gate = DigestGate(minGap: Duration(hours: 4));

      expect(await gate.shouldShow(), isFalse);
    });

    test('a zero minGap always allows showing again', () async {
      SharedPreferences.setMockInitialValues({});
      const gate = DigestGate(minGap: Duration.zero);

      await gate.markShown();

      expect(await gate.shouldShow(), isTrue);
    });
  });
}
