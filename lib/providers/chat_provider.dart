import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/natsume_status.dart';
import '../services/backend_client.dart';
import '../services/chat_history_store.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._api, {ChatHistoryStore history = const ChatHistoryStore()})
      : _history = history {
    _loadHistory();
  }

  final BackendClient _api;
  final ChatHistoryStore _history;

  final List<ChatMessage> messages = [];
  NatsumeStatus status = NatsumeStatus.empty;
  bool sending = false;
  bool loadingStatus = false;
  String? error;

  Future<void> _loadHistory() async {
    final stored = await _history.load();
    if (stored.isEmpty) return;
    messages.addAll(stored);
    notifyListeners();
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || sending) return;

    final userMsg = ChatMessage(role: MessageRole.user, text: text.trim(), ts: DateTime.now());
    messages.add(userMsg);
    sending = true;
    error = null;
    notifyListeners();

    try {
      final reply = await _api.sendChat(text.trim());
      messages.add(reply);
    } on ApiException catch (e) {
      error = 'Erreur ${e.statusCode} — ${e.message}';
    } catch (e) {
      error = 'Connexion impossible';
    } finally {
      sending = false;
      notifyListeners();
      // Best-effort — a failed save only costs the next launch this turn's messages,
      // never the running session.
      unawaited(_history.save(messages));
    }
  }

  Future<void> refreshStatus() async {
    loadingStatus = true;
    notifyListeners();
    try {
      status = await _api.getStatus();
      error = null;
    } catch (_) {
      // keep stale status
    } finally {
      loadingStatus = false;
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}
