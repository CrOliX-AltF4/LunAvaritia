import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/assistant_identity.dart';
import '../models/chat_message.dart';
import '../models/companion_status.dart';
import '../services/backend_client.dart';
import '../services/chat_history_store.dart';
import '../services/identity_store.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(
    this._api, {
    ChatHistoryStore history = const ChatHistoryStore(),
    IdentityStore identityStore = const IdentityStore(),
  })  : _history = history,
        _identityStore = identityStore {
    _loadHistory();
    _loadIdentity();
  }

  final BackendClient _api;
  final ChatHistoryStore _history;
  final IdentityStore _identityStore;

  final List<ChatMessage> messages = [];

  /// Who answers, as the server last said (cached, so the right name shows before the network answers).
  AssistantIdentity identity = AssistantIdentity.unknown;
  CompanionStatus status = CompanionStatus.empty;
  bool sending = false;
  bool loadingStatus = false;
  String? error;

  Future<void> _loadHistory() async {
    final stored = await _history.load();
    if (stored.isEmpty) return;
    messages.addAll(stored);
    notifyListeners();
  }

  Future<void> _loadIdentity() async {
    final cached = await _identityStore.load();
    if (cached == null) return;
    identity = cached;
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
    } on BackendError catch (e) {
      // The precise cause (unreachable, too slow, token refused, server error) — never a blanket
      // "Connexion impossible" (live check 2026-09-29).
      error = e.message;
    } catch (e) {
      error = 'Erreur inattendue : $e';
    } finally {
      sending = false;
      notifyListeners();
      // Best-effort — a failed save only costs the next launch this turn's messages,
      // never the running session.
      unawaited(_history.save(messages));
    }
  }

  /// Asks the server who answers, then — only for the hub's companion — her mood/energy/affinity.
  Future<void> refreshStatus() async {
    loadingStatus = true;
    notifyListeners();
    try {
      identity = await _api.getIdentity();
      unawaited(_identityStore.save(identity));
      status = identity.isCompanion ? await _api.getStatus() : CompanionStatus.empty;
      error = null;
    } catch (_) {
      // keep the cached identity and the stale status — a failed refresh is not worth a banner
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
