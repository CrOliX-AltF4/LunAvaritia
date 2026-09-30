import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/models/alert.dart';
import 'package:lunavaritia/models/assistant_identity.dart';
import 'package:lunavaritia/models/chat_message.dart';
import 'package:lunavaritia/models/companion_status.dart';
import 'package:lunavaritia/providers/chat_provider.dart';
import 'package:lunavaritia/screens/chat_screen.dart';
import 'package:lunavaritia/services/backend_client.dart';

class _FakeBackend implements BackendClient {
  _FakeBackend({this.identity = AssistantIdentity.unknown});

  final AssistantIdentity identity;

  @override
  Future<ChatMessage> sendChat(String text) async =>
      ChatMessage(role: MessageRole.assistant, text: 'pong', ts: DateTime.now());

  @override
  Future<CompanionStatus> getStatus() async => CompanionStatus.empty;

  @override
  Future<AssistantIdentity> getIdentity() async => identity;

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

Widget _buildScreen({AssistantIdentity identity = AssistantIdentity.unknown}) {
  return ChangeNotifierProvider<ChatProvider>(
    create: (_) => ChatProvider(_FakeBackend(identity: identity)),
    child: const MaterialApp(home: ChatScreen()),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ChatScreen', () {
    testWidgets("shows empty state with the server's name when no messages", (tester) async {
      await tester.pumpWidget(_buildScreen(identity: const AssistantIdentity(name: 'Iris', isCompanion: false)));
      await tester.pumpAndSettle();

      expect(find.text('Écris à Iris'), findsOneWidget);
    });

    testWidgets('the title is the name the server gives, never one written in the app (ADR-020 D2)', (tester) async {
      await tester.pumpWidget(_buildScreen(identity: const AssistantIdentity(name: 'Iris', isCompanion: false)));
      await tester.pumpAndSettle();

      expect(find.text('Iris'), findsOneWidget);
      expect(find.text('Natsume'), findsNothing);
    });

    testWidgets("no mood or energy for LunAcedia's assistant", (tester) async {
      await tester.pumpWidget(_buildScreen(identity: const AssistantIdentity(name: 'Iris', isCompanion: false)));
      await tester.pumpAndSettle();

      expect(find.text('Énergie'), findsNothing);
    });

    testWidgets("mood and energy show when the hub's companion answers", (tester) async {
      await tester.pumpWidget(_buildScreen(identity: const AssistantIdentity(name: 'Hoshi', isCompanion: true)));
      await tester.pumpAndSettle();

      expect(find.text('Énergie'), findsOneWidget);
    });

    testWidgets('shows message input field', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
