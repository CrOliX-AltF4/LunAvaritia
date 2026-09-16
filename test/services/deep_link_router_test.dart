import 'package:flutter_test/flutter_test.dart';
import 'package:lunavaritia/services/deep_link_router.dart';

void main() {
  group('DeepLinkRouter', () {
    test('pending is null before any request', () {
      final router = DeepLinkRouter.instance;
      router.consume(); // clear any leftover state from another test in this isolate
      expect(router.pending, isNull);
    });

    test('requestTab sets pending and notifies listeners', () {
      final router = DeepLinkRouter.instance;
      var notified = false;
      router.addListener(() => notified = true);

      router.requestTab(AppTab.alerts);

      expect(router.pending, AppTab.alerts);
      expect(notified, isTrue);
      router.consume();
    });

    test('consume clears pending', () {
      final router = DeepLinkRouter.instance;
      router.requestTab(AppTab.chat);
      router.consume();
      expect(router.pending, isNull);
    });
  });

  group('resolveDeepLinkTarget', () {
    test('routes a Natsume-shaped payload (alertId/source) to alerts', () {
      expect(
        resolveDeepLinkTarget({'alertId': 'a1', 'source': 'email'}),
        AppTab.alerts,
      );
    });

    test('routes a LunAcedia-shaped payload (type/source/dedupeKey/priority) to alerts', () {
      expect(
        resolveDeepLinkTarget({
          'type': 'email.new',
          'source': 'gmail',
          'dedupeKey': 'gmail-123',
          'priority': 'urgent',
        }),
        AppTab.alerts,
      );
    });

    test('routes an empty/unknown payload to alerts too (only destination today)', () {
      expect(resolveDeepLinkTarget({}), AppTab.alerts);
    });
  });
}
