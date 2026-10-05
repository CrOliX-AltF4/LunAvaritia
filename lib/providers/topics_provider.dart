import 'package:flutter/foundation.dart';

import '../models/topic.dart';
import '../services/backend_client.dart';

/// The list of topics (drawer) and the gestures on a topic: open, rename, archive, delete. All stored by the
/// server — the app keeps nothing of its own.
class TopicsProvider extends ChangeNotifier {
  TopicsProvider(this._api);

  final BackendClient _api;

  List<Topic> topics = const [];
  List<Topic> archived = const [];
  bool loading = false;
  String? error;

  /// A turn that opened a topic, kept for the topic screen so it shows the first answer without asking again.
  TurnResult? lastOpened;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      topics = await _api.topics.list();
      error = null;
    } on BackendError catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Erreur inattendue : $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshArchived() async {
    try {
      archived = await _api.topics.list(archived: true);
      notifyListeners();
    } catch (_) {}
  }

  /// Opens a topic with its first message. Throws a [BackendError] the caller shows where the user typed.
  Future<TurnResult> open(String text, {String? aboutKey}) async {
    final result = await _api.topics.open(text, aboutKey: aboutKey);
    lastOpened = result;
    _upsert(result.topic);
    return result;
  }

  /// A turn changed a topic (its title arrives in the background, its activity moves it up).
  void touched(Topic topic) => _upsert(topic);

  Future<void> rename(String id, String title) async => _upsert(await _api.topics.update(id, title: title));

  Future<void> setArchived(String id, bool value) async {
    final topic = await _api.topics.update(id, archived: value);
    topics = [for (final t in topics) if (t.id != id) t];
    archived = [for (final t in archived) if (t.id != id) t];
    if (value) {
      archived = [topic, ...archived];
    } else {
      _upsert(topic);
    }
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _api.topics.delete(id);
    topics = [for (final t in topics) if (t.id != id) t];
    archived = [for (final t in archived) if (t.id != id) t];
    notifyListeners();
  }

  Topic? byId(String id) {
    for (final t in [...topics, ...archived]) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _upsert(Topic topic) {
    if (topic.archived) return;
    topics = [topic, for (final t in topics) if (t.id != topic.id) t]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }
}
