import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

const _keyHistory = 'chat_history';

/// Local-only persistence for the chat transcript (LunAvaritia gap #1 — messages used to
/// live purely in ChatProvider's in-memory list, lost on every app close). Capped so the
/// stored JSON blob can't grow unbounded over a long-lived install.
class ChatHistoryStore {
  const ChatHistoryStore({this.maxMessages = 200});

  final int maxMessages;

  Future<List<ChatMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .cast<Map<String, dynamic>>()
          .map(ChatMessage.fromLocalJson)
          .toList();
    } catch (_) {
      // Corrupt/old-format blob — start fresh rather than crash the chat screen.
      return [];
    }
  }

  Future<void> save(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final capped = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;
    await prefs.setString(_keyHistory, jsonEncode(capped.map((m) => m.toLocalJson()).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }
}
