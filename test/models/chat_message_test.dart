import 'package:flutter_test/flutter_test.dart';

import 'package:lunavaritia/models/chat_message.dart';

void main() {
  group('ChatMessage.toLocalJson / fromLocalJson', () {
    test('round-trips a user message', () {
      final ts = DateTime.parse('2026-09-16T08:00:00.000Z');
      final msg = ChatMessage(id: 'u1', role: MessageRole.user, text: 'Hi', ts: ts);

      final restored = ChatMessage.fromLocalJson(msg.toLocalJson());

      expect(restored.id, 'u1');
      expect(restored.role, MessageRole.user);
      expect(restored.text, 'Hi');
      expect(restored.ts, ts);
    });

    test('round-trips a natsume message', () {
      final msg = ChatMessage(role: MessageRole.natsume, text: 'Yo.', ts: DateTime.now());
      final restored = ChatMessage.fromLocalJson(msg.toLocalJson());
      expect(restored.role, MessageRole.natsume);
    });

    test('fromLocalJson falls back to now() on an unparseable timestamp', () {
      final before = DateTime.now();
      final restored = ChatMessage.fromLocalJson({'role': 'user', 'text': 'Hi', 'ts': 'garbage'});
      expect(restored.ts.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });

    test('fromLocalJson defaults text to empty string when missing', () {
      final restored = ChatMessage.fromLocalJson({'role': 'user'});
      expect(restored.text, '');
    });
  });
}
