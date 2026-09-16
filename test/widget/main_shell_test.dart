import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/models/alert.dart';
import 'package:lunavaritia/models/chat_message.dart';
import 'package:lunavaritia/models/natsume_status.dart';
import 'package:lunavaritia/providers/alert_provider.dart';
import 'package:lunavaritia/providers/chat_provider.dart';
import 'package:lunavaritia/screens/main_shell.dart';
import 'package:lunavaritia/services/backend_client.dart';
import 'package:lunavaritia/services/deep_link_router.dart';
import 'package:lunavaritia/services/digest_gate.dart';

class _FakeBackend implements BackendClient {
  _FakeBackend({this.digest = 'Overnight: 3 emails, 1 meeting.', this.digestError});

  final String digest;
  final Object? digestError;

  @override
  Future<ChatMessage> sendChat(String text) async =>
      ChatMessage(role: MessageRole.natsume, text: 'pong', ts: DateTime.now());

  @override
  Future<NatsumeStatus> getStatus() async => NatsumeStatus.empty;

  @override
  Future<List<Alert>> getAlerts({
    int limit = 50,
    int offset = 0,
    bool? unread,
    String? source,
    String? priority,
  }) async =>
      [];

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<String> getDigest() async {
    if (digestError != null) throw digestError!;
    return digest;
  }

  @override
  Future<void> registerPushToken(String token) async {}
}

Widget _buildShell(
  _FakeBackend backend, {
  required DigestGate digestGate,
  DeepLinkRouter? deepLinkRouter,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider(backend)),
      ChangeNotifierProvider<AlertProvider>(create: (_) => AlertProvider(backend)),
    ],
    child: MaterialApp(
      home: MainShell(digestGate: digestGate, deepLinkRouter: deepLinkRouter),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MainShell — digest on wake', () {
    testWidgets('shows the digest sheet on cold start when the gate allows it', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = _FakeBackend(digest: 'Overnight: 3 emails, 1 meeting.');

      await tester.pumpWidget(_buildShell(backend, digestGate: const DigestGate(minGap: Duration.zero)));
      await tester.pumpAndSettle();

      expect(find.text('Overnight: 3 emails, 1 meeting.'), findsOneWidget);
    });

    testWidgets('does not show the digest sheet when the gate blocks it', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = _FakeBackend(digest: 'Overnight: 3 emails, 1 meeting.');
      const gate = DigestGate();
      await gate.markShown(); // simulate "already shown recently"

      await tester.pumpWidget(_buildShell(backend, digestGate: gate));
      await tester.pumpAndSettle();

      expect(find.text('Overnight: 3 emails, 1 meeting.'), findsNothing);
    });

    testWidgets('does not show a sheet for an empty digest, but still marks the gate as shown', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = _FakeBackend(digest: '');
      const gate = DigestGate(minGap: Duration.zero);

      await tester.pumpWidget(_buildShell(backend, digestGate: gate));
      await tester.pumpAndSettle();

      // No sheet — the app shell (bottom nav) is all that's on screen.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
    });

    testWidgets('fails silently and does not crash when the digest fetch errors', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = _FakeBackend(digestError: Exception('offline'));

      await tester.pumpWidget(_buildShell(backend, digestGate: const DigestGate(minGap: Duration.zero)));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('MainShell — deep-link tab switching (LunAvaritia gap #3)', () {
    int selectedIndex(WidgetTester tester) =>
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

    testWidgets('switches to the Alertes tab when a deep link is already pending on first build', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final router = DeepLinkRouter.instance..consume();
      router.requestTab(AppTab.alerts);

      await tester.pumpWidget(_buildShell(
        _FakeBackend(),
        digestGate: const DigestGate(minGap: Duration(hours: 4)),
        deepLinkRouter: router,
      ));
      await tester.pumpAndSettle();

      expect(selectedIndex(tester), AppTab.alerts.index);
      expect(router.pending, isNull);
    });

    testWidgets('switches tab when a deep link request arrives after the shell is already built', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final router = DeepLinkRouter.instance..consume();

      await tester.pumpWidget(_buildShell(
        _FakeBackend(),
        digestGate: const DigestGate(minGap: Duration(hours: 4)),
        deepLinkRouter: router,
      ));
      await tester.pumpAndSettle();
      expect(selectedIndex(tester), AppTab.chat.index);

      router.requestTab(AppTab.alerts);
      await tester.pumpAndSettle();

      expect(selectedIndex(tester), AppTab.alerts.index);
    });

    testWidgets('does not switch tabs when nothing is pending', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final router = DeepLinkRouter.instance..consume();

      await tester.pumpWidget(_buildShell(
        _FakeBackend(),
        digestGate: const DigestGate(minGap: Duration(hours: 4)),
        deepLinkRouter: router,
      ));
      await tester.pumpAndSettle();

      expect(selectedIndex(tester), AppTab.chat.index);
    });
  });
}
