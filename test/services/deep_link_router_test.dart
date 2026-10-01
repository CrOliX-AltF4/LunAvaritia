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

      router.request(DeepLinkTarget.box);

      expect(router.pending, DeepLinkTarget.box);
      expect(notified, isTrue);
      router.consume();
    });

    test('consume clears pending', () {
      final router = DeepLinkRouter.instance;
      router.request(DeepLinkTarget.box);
      router.consume();
      expect(router.pending, isNull);
    });
  });

  group('resolveDeepLinkTarget', () {
    test("routes the hub's payload (alertId/source/key) to the box", () {
      expect(resolveDeepLinkTarget({'alertId': 'a1', 'source': 'email', 'key': 'email-1'}), DeepLinkTarget.box);
    });

    test("routes LunAcedia's payload (type/source/dedupeKey/priority) to the box", () {
      expect(
        resolveDeepLinkTarget({'type': 'email.new', 'source': 'gmail', 'dedupeKey': 'gmail-123', 'priority': 'urgent'}),
        DeepLinkTarget.box,
      );
    });

    test('routes an empty/unknown payload to the box too (only destination today)', () {
      expect(resolveDeepLinkTarget({}), DeepLinkTarget.box);
    });
  });
}
