import 'package:flutter/foundation.dart';

import '../models/topic.dart';
import '../services/backend_client.dart';

/// How long LunAcedia keeps an action waiting for the user — past that it is dropped, never executed.
/// When an action carries no deadline: an older LunAcedia kept one 5 minutes (ADR-020 §5.11 made it durable).
const pendingActionLifetime = Duration(minutes: 5);

/// Where an action waiting on the user stands on this phone.
enum DecisionState { waiting, deciding, confirmed, cancelled, expired, failed }

/// One open topic: its messages (paged from the server), a turn at a time, and the decisions on the actions its
/// answers wait on (ADR-020 §5.8 (a): an action is settled where it appears).
class TopicController extends ChangeNotifier {
  TopicController(this._api, this.topicId, {DateTime Function() now = DateTime.now, TurnResult? opened})
      : _now = now {
    if (opened != null) {
      topic = opened.topic;
      messages.addAll([opened.userMessage, opened.message]);
    }
  }

  final BackendClient _api;
  final String topicId;
  final DateTime Function() _now;

  Topic? topic;
  final List<TopicMessage> messages = [];
  bool hasMore = false;
  bool loading = false;
  bool loadingOlder = false;
  bool sending = false;
  String? error;

  /// The text of a turn that failed — given back to the composer so nothing typed is lost.
  String? unsent;

  final Map<String, DecisionState> _decisions = {};
  final Map<String, String> _decisionErrors = {};

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _api.topics.page(topicId);
      topic = page.topic;
      messages
        ..clear()
        ..addAll(page.messages);
      hasMore = page.hasMore;
    } on BackendError catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Erreur inattendue : $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadOlder() async {
    if (!hasMore || loadingOlder || messages.isEmpty) return;
    loadingOlder = true;
    notifyListeners();
    try {
      final page = await _api.topics.page(topicId, before: messages.first.id);
      messages.insertAll(0, page.messages);
      hasMore = page.hasMore;
    } catch (_) {
      // the button stays — the user can try again
    } finally {
      loadingOlder = false;
      notifyListeners();
    }
  }

  /// One turn. Returns the topic as the server now has it (for the drawer), or null when the turn failed.
  Future<Topic?> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) return null;
    sending = true;
    error = null;
    unsent = null;
    notifyListeners();
    try {
      final result = await _api.topics.send(topicId, trimmed);
      topic = result.topic;
      messages.addAll([result.userMessage, result.message]);
      return result.topic;
    } on BackendError catch (e) {
      error = e.message;
      await _afterFailedTurn(trimmed);
      return null;
    } catch (e) {
      error = 'Erreur inattendue : $e';
      await _afterFailedTurn(trimmed);
      return null;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  /// A failed turn may still have stored the message (the server keeps it when the answer fails): show the topic as
  /// the server has it, and give the text back to the composer only if it was not kept — never twice.
  Future<void> _afterFailedTurn(String text) async {
    try {
      final page = await _api.topics.page(topicId);
      topic = page.topic;
      messages
        ..clear()
        ..addAll(page.messages);
      hasMore = page.hasMore;
      final last = messages.isEmpty ? null : messages.last;
      if (last != null && last.role == TopicRole.user && last.text == text) return;
    } catch (_) {
      // out of reach: keep what is shown
    }
    unsent = text;
  }

  DecisionState decisionOf(TopicMessage message, AgentAction action) {
    final id = action.id ?? '';
    final known = _decisions[id];
    if (known != null) return known;
    return remainingFor(message, action) > Duration.zero ? DecisionState.waiting : DecisionState.expired;
  }

  /// How long LunAcedia still keeps this action waiting: until its own deadline, or 5 minutes from an older server.
  Duration remainingFor(TopicMessage message, AgentAction action) =>
      (action.expiresAt ?? message.at.add(pendingActionLifetime)).difference(_now());

  String? decisionErrorOf(AgentAction action) => _decisionErrors[action.id ?? ''];

  Future<void> decide(AgentAction action, {required bool confirm}) async {
    final id = action.id;
    if (id == null || !action.isDecidable) return;
    _decisions[id] = DecisionState.deciding;
    _decisionErrors.remove(id);
    notifyListeners();
    try {
      await _api.topics.decide(id, confirm: confirm);
      _decisions[id] = confirm ? DecisionState.confirmed : DecisionState.cancelled;
    } on BackendError catch (e) {
      // 410 from the hub, 404 from LunAcedia: it is no longer waiting — nothing was done.
      if (e.statusCode == 410 || e.statusCode == 404) {
        _decisions[id] = DecisionState.expired;
      } else {
        _decisions[id] = DecisionState.failed;
        _decisionErrors[id] = e.message;
      }
    } catch (e) {
      _decisions[id] = DecisionState.failed;
      _decisionErrors[id] = 'Erreur inattendue : $e';
    } finally {
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}
