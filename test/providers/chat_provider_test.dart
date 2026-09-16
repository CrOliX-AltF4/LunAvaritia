import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/models/alert.dart';
import 'package:lunavaritia/models/chat_message.dart';
import 'package:lunavaritia/models/natsume_status.dart';
import 'package:lunavaritia/providers/chat_provider.dart';
import 'package:lunavaritia/services/backend_client.dart';
import 'package:lunavaritia/services/chat_history_store.dart';

class _FakeBackend implements BackendClient {
  _FakeBackend({this.replyText = 'pong', this.sendError});

  final String replyText;
  final Object? sendError;

  @override
  Future<ChatMessage> sendChat(String text) async {
    if (sendError != null) throw sendError!;
    return ChatMessage(role: MessageRole.natsume, text: replyText, ts: DateTime.now());
  }

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
  Future<String> getDigest() async => '';

  @override
  Future<void> registerPushToken(String token) async {}
}

Future<void> _pumpMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatProvider — history persistence (LunAvaritia gap #1)', () {
    test('loads previously saved history on construction', () async {
      SharedPreferences.setMockInitialValues({});
      const store = ChatHistoryStore();
      await store.save([ChatMessage(id: 'm1', role: MessageRole.user, text: 'Hi', ts: DateTime.now())]);

      final provider = ChatProvider(_FakeBackend(), history: store);
      await _pumpMicrotasks();

      expect(provider.messages, hasLength(1));
      expect(provider.messages.first.text, 'Hi');
    });

    test('starts with no messages when nothing was saved before', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ChatProvider(_FakeBackend(), history: const ChatHistoryStore());
      await _pumpMicrotasks();

      expect(provider.messages, isEmpty);
    });

    test('persists both the user message and the reply after a successful send', () async {
      SharedPreferences.setMockInitialValues({});
      const store = ChatHistoryStore();
      final provider = ChatProvider(_FakeBackend(replyText: 'Yo.'), history: store);
      await _pumpMicrotasks();

      await provider.send('Hello');
      await _pumpMicrotasks();

      final persisted = await store.load();
      expect(persisted, hasLength(2));
      expect(persisted[0].text, 'Hello');
      expect(persisted[1].text, 'Yo.');
    });

    test('still persists the user message even when the reply fails', () async {
      SharedPreferences.setMockInitialValues({});
      const store = ChatHistoryStore();
      final provider = ChatProvider(_FakeBackend(sendError: Exception('offline')), history: store);
      await _pumpMicrotasks();

      await provider.send('Hello');
      await _pumpMicrotasks();

      final persisted = await store.load();
      expect(persisted, hasLength(1));
      expect(persisted[0].text, 'Hello');
    });
  });
}
