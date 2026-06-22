import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lunavaritia/models/alert.dart';
import 'package:lunavaritia/models/chat_message.dart';
import 'package:lunavaritia/models/natsume_status.dart';
import 'package:lunavaritia/providers/alert_provider.dart';
import 'package:lunavaritia/screens/alert_feed_screen.dart';
import 'package:lunavaritia/services/backend_client.dart';

class _FakeBackend implements BackendClient {
  final List<Alert> _alerts;
  _FakeBackend({List<Alert>? alerts}) : _alerts = alerts ?? [];

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
      _alerts;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<String> getDigest() async => 'digest';

  @override
  Future<void> registerPushToken(String token) async {}
}

Widget _buildScreen({List<Alert>? alerts}) {
  return ChangeNotifierProvider<AlertProvider>(
    create: (_) => AlertProvider(_FakeBackend(alerts: alerts)),
    child: const MaterialApp(home: AlertFeedScreen()),
  );
}

void main() {
  group('AlertFeedScreen', () {
    testWidgets('shows Alertes title in AppBar', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Alertes'), findsOneWidget);
    });

    testWidgets('shows empty state when no alerts', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Aucune alerte'), findsOneWidget);
    });

    testWidgets('shows alert title when alerts are present', (tester) async {
      final alert = Alert(
        id: 'test-1',
        type: 'github',
        source: AlertSource.github,
        title: 'PR merged',
        priority: AlertPriority.normal,
        ts: DateTime(2026, 6, 22),
        read: false,
      );

      await tester.pumpWidget(_buildScreen(alerts: [alert]));
      await tester.pumpAndSettle();

      expect(find.text('PR merged'), findsOneWidget);
    });
  });
}
