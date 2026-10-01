import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/models/alert.dart';
import 'package:lunavaritia/models/assistant_identity.dart';
import 'package:lunavaritia/models/chat_message.dart';
import 'package:lunavaritia/models/companion_status.dart';
import 'package:lunavaritia/providers/alert_provider.dart';
import 'package:lunavaritia/providers/chat_provider.dart';
import 'package:lunavaritia/screens/main_shell.dart';
import 'package:lunavaritia/services/backend_client.dart';
import 'package:lunavaritia/services/deep_link_router.dart';
import 'package:lunavaritia/services/digest_gate.dart';
import 'package:lunavaritia/services/update_checker.dart';

class _FakeBackend implements BackendClient {
  _FakeBackend({this.digest = 'Overnight: 3 emails, 1 meeting.', this.digestError});

  final String digest;
  final Object? digestError;

  @override
  Future<ChatMessage> sendChat(String text) async =>
      ChatMessage(role: MessageRole.assistant, text: 'pong', ts: DateTime.now());

  @override
  Future<CompanionStatus> getStatus() async => CompanionStatus.empty;

  @override
  Future<AssistantIdentity> getIdentity() async => AssistantIdentity.unknown;

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

/// Answers a fixed status — the real checker would ask GitHub.
class _FakeUpdateChecker extends UpdateChecker {
  _FakeUpdateChecker(this.status);
  final UpdateStatus status;
  int calls = 0;

  @override
  Future<UpdateStatus> check() async {
    calls++;
    return status;
  }
}

Widget _buildShell(
  _FakeBackend backend, {
  required DigestGate digestGate,
  DeepLinkRouter? deepLinkRouter,
  UpdateChecker? updateChecker,
  bool pairingNeeded = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider(backend)),
      ChangeNotifierProvider<AlertProvider>(create: (_) => AlertProvider(backend)),
    ],
    child: MaterialApp(
      home: MainShell(
        digestGate: digestGate,
        deepLinkRouter: deepLinkRouter,
        updateChecker: updateChecker ?? _FakeUpdateChecker(const UpToDate('1.3.1')),
        pairingNeeded: pairingNeeded,
      ),
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

  group('MainShell — pairing banner (ADR-020 M3)', () {
    const gate = DigestGate(minGap: Duration(hours: 4));

    testWidgets('says the phone is not paired and leads to the settings', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildShell(_FakeBackend(digest: ''), digestGate: gate, pairingNeeded: true));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialBanner), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Paramètres'));
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, AppTab.settings.index);
      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('says nothing when the phone is paired', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildShell(_FakeBackend(digest: ''), digestGate: gate));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsNothing);
    });
  });

  group('MainShell — update on launch (ADR-020 M1)', () {
    const available = UpdateAvailable(AvailableUpdate(version: '1.4.0', downloadUrl: 'https://x/app.apk'));

    testWidgets('offers a newer release once, with a download action', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final checker = _FakeUpdateChecker(available);
      await tester.pumpWidget(_buildShell(
        _FakeBackend(),
        digestGate: const DigestGate(minGap: Duration(hours: 4)),
        deepLinkRouter: DeepLinkRouter.instance..consume(),
        updateChecker: checker,
      ));
      await tester.pump();
      await tester.pump();

      expect(checker.calls, 1);
      expect(find.text('Version 1.4.0 disponible'), findsOneWidget);
      expect(find.text('Télécharger'), findsOneWidget);
      expect(await UpdateChecker.shouldNotify('1.4.0'), isFalse);
    });

    testWidgets('does not offer the same version again on the next launch', (tester) async {
      SharedPreferences.setMockInitialValues({'update_notified_version': '1.4.0'});
      await tester.pumpWidget(_buildShell(
        _FakeBackend(),
        digestGate: const DigestGate(minGap: Duration(hours: 4)),
        deepLinkRouter: DeepLinkRouter.instance..consume(),
        updateChecker: _FakeUpdateChecker(available),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Version 1.4.0 disponible'), findsNothing);
    });

    testWidgets('says nothing when up to date or when GitHub cannot be reached', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildShell(
        _FakeBackend(),
        digestGate: const DigestGate(minGap: Duration(hours: 4)),
        deepLinkRouter: DeepLinkRouter.instance..consume(),
        updateChecker: _FakeUpdateChecker(const UpdateUnknown('GitHub injoignable')),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
