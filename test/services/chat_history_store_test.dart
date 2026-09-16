import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/models/chat_message.dart';
import 'package:lunavaritia/services/chat_history_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatHistoryStore', () {
    test('load returns an empty list when nothing was ever saved', () async {
      SharedPreferences.setMockInitialValues({});
      const store = ChatHistoryStore();

      expect(await store.load(), isEmpty);
    });

    test('save then load round-trips role/text/ts', () async {
      SharedPreferences.setMockInitialValues({});
      const store = ChatHistoryStore();
      final ts = DateTime.parse('2026-09-16T08:00:00.000Z');
      final messages = [
        ChatMessage(id: 'u1', role: MessageRole.user, text: 'Hi', ts: ts),
        ChatMessage(id: 'n1', role: MessageRole.natsume, text: 'Hey.', ts: ts),
      ];

      await store.save(messages);
      final loaded = await store.load();

      expect(loaded, hasLength(2));
      expect(loaded[0].id, 'u1');
      expect(loaded[0].role, MessageRole.user);
      expect(loaded[0].text, 'Hi');
      expect(loaded[0].ts, ts);
      expect(loaded[1].role, MessageRole.natsume);
    });

    test('caps stored history at maxMessages, keeping the most recent', () async {
      SharedPreferences.setMockInitialValues({});
      const store = ChatHistoryStore(maxMessages: 3);
      final messages = List.generate(
        5,
        (i) => ChatMessage(id: 'm$i', role: MessageRole.user, text: 'msg $i', ts: DateTime.now()),
      );

      await store.save(messages);
      final loaded = await store.load();

      expect(loaded, hasLength(3));
      expect(loaded.map((m) => m.id), ['m2', 'm3', 'm4']);
    });

    test('load returns empty list on corrupt stored data instead of throwing', () async {
      SharedPreferences.setMockInitialValues({'chat_history': 'not json'});
      const store = ChatHistoryStore();

      expect(await store.load(), isEmpty);
    });

    test('clear removes the stored history', () async {
      SharedPreferences.setMockInitialValues({});
      const store = ChatHistoryStore();
      await store.save([ChatMessage(role: MessageRole.user, text: 'Hi', ts: DateTime.now())]);

      await store.clear();

      expect(await store.load(), isEmpty);
    });
  });
}
