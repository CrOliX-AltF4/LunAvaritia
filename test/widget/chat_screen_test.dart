import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lunavaritia/models/alert.dart';
import 'package:lunavaritia/models/chat_message.dart';
import 'package:lunavaritia/models/natsume_status.dart';
import 'package:lunavaritia/providers/chat_provider.dart';
import 'package:lunavaritia/screens/chat_screen.dart';
import 'package:lunavaritia/services/backend_client.dart';

class _FakeBackend implements BackendClient {
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
  Future<String> getDigest() async => 'digest';

  @override
  Future<void> registerPushToken(String token) async {}
}

Widget _buildScreen() {
  return ChangeNotifierProvider<ChatProvider>(
    create: (_) => ChatProvider(_FakeBackend()),
    child: const MaterialApp(home: ChatScreen()),
  );
}

void main() {
  group('ChatScreen', () {
    testWidgets('shows empty state when no messages', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Parle à Natsume'), findsOneWidget);
    });

    testWidgets('shows Natsume title in AppBar', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Natsume'), findsOneWidget);
    });

    testWidgets('shows message input field', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
