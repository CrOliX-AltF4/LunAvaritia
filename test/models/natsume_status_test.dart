import 'package:flutter_test/flutter_test.dart';

import 'package:lunavaritia/models/natsume_status.dart';

void main() {
  group('NatsumeStatus.fromJson', () {
    // Regression test: /api/mobile/status has always sent affinityTier as a number
    // (admin_router.ts's affinityTier() helper) — a prior version of this model cast
    // it `as String?`, which throws a TypeError on a non-null, non-String value rather
    // than falling back to a default. Every real call to getStatus() crashed here.
    test('parses a numeric affinityTier without throwing', () {
      final status = NatsumeStatus.fromJson({
        'mood': 'happy',
        'energy': 0.8,
        'affinityTier': 3,
        'pendingAlerts': 2,
      });
      expect(status.affinityTier, 3);
      expect(status.mood, 'happy');
      expect(status.energy, 0.8);
      expect(status.pendingAlerts, 2);
    });

    test('defaults affinityTier to 0 when missing', () {
      final status = NatsumeStatus.fromJson({'mood': 'neutral', 'energy': 0.5, 'pendingAlerts': 0});
      expect(status.affinityTier, 0);
    });

    test('defaults every field when given an empty payload', () {
      final status = NatsumeStatus.fromJson({});
      expect(status.mood, 'neutral');
      expect(status.energy, 0.5);
      expect(status.affinityTier, 0);
      expect(status.pendingAlerts, 0);
    });
  });
}
