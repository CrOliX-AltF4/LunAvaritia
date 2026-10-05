import 'package:flutter_test/flutter_test.dart';
import 'package:lunavaritia/services/deep_link_router.dart';

void main() {
  group('DeepLinkRouter', () {
    test('pending is null before any request', () {
      final router = DeepLinkRouter.instance;
      router.consume(); // clear any leftover state from another test in this isolate
      expect(router.pending, isNull);
    });

    test('request sets pending and notifies listeners', () {
      final router = DeepLinkRouter.instance;
      var notified = false;
      router.addListener(() => notified = true);

      router.request(const DeepLinkTarget.box(boxKey: 'email-1'));

      expect(router.pending?.boxKey, 'email-1');
      expect(notified, isTrue);
      router.consume();
    });

    test('consume clears pending', () {
      final router = DeepLinkRouter.instance;
      router.request(const DeepLinkTarget.box());
      router.consume();
      expect(router.pending, isNull);
    });

    test('a nudge tells the box to read itself again', () {
      final router = DeepLinkRouter.instance;
      final before = router.boxNudges.value;
      router.nudgeBox();
      expect(router.boxNudges.value, before + 1);
    });
  });

  // ADR-020 §5.10 M4c — a notification opens the item it announces, read in full; the box when it announces nothing in it.
  group('resolveDeepLinkTarget', () {
    test("the hub's payload: its alert's box item (key)", () {
      expect(resolveDeepLinkTarget({'alertId': 'a1', 'source': 'email', 'key': 'email-1'}).boxKey, 'email-1');
    });

    test("LunAcedia's payload: the item's dedupeKey", () {
      expect(
        resolveDeepLinkTarget(
            {'type': 'email.received', 'source': 'email', 'dedupeKey': 'email-123', 'priority': 'urgent'}).boxKey,
        'email-123',
      );
    });

    test('a hub alert about nothing in the box, or an unknown payload: the box', () {
      expect(resolveDeepLinkTarget({'alertId': 'a1', 'source': 'system'}).boxKey, isNull);
      expect(resolveDeepLinkTarget({}).boxKey, isNull);
    });
  });
}
