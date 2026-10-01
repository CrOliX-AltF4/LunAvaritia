import '../models/topic.dart';
import 'http_transport.dart';

/// The topics contract (ADR-020 amendment 1) — the same paths and shapes on LunAcedia (standalone) and on the hub
/// (wired), only the prefix changes. Also the decision on an action a topic answer is waiting on (§5.8 (a)).
class TopicApi {
  TopicApi(this._http, {required this.topicsPath, required this.actionsPath});

  /// LunAcedia: talks to it directly.
  TopicApi.lunacedia(HttpTransport http) : this(http, topicsPath: '/api/conversations', actionsPath: '/api/actions');

  /// The hub: the Core answers, and relays a decision to LunAcedia (hub-and-spoke).
  TopicApi.hub(HttpTransport http)
      : this(http, topicsPath: '/api/mobile/conversations', actionsPath: '/api/mobile/actions');

  final HttpTransport _http;
  final String topicsPath;
  final String actionsPath;

  String _one(String id) => '$topicsPath/${Uri.encodeComponent(id)}';

  /// Most recent activity first.
  Future<List<Topic>> list({bool archived = false}) async {
    final data = asObject(await _http.get('$topicsPath?archived=$archived'));
    return [
      for (final t in (data['conversations'] as List<dynamic>? ?? const []))
        if (t is Map<String, dynamic>) Topic.fromJson(t),
    ];
  }

  /// Opens a topic with its first message, and returns the first answer. [aboutKey]: the box item it is about.
  Future<TurnResult> open(String text, {String? aboutKey}) async => TurnResult.fromJson(asObject(await _http.post(
        topicsPath,
        body: {'text': text, if (aboutKey != null) 'about': {'key': aboutKey}},
        timeout: HttpTransport.chatTimeout,
      )));

  /// The last [limit] messages, or the ones just before message [before] — oldest first.
  Future<TopicPage> page(String id, {String? before, int limit = 30}) async {
    final query = 'limit=$limit${before != null ? '&before=${Uri.encodeComponent(before)}' : ''}';
    return TopicPage.fromJson(asObject(await _http.get('${_one(id)}?$query')));
  }

  Future<TurnResult> send(String id, String text) async => TurnResult.fromJson(asObject(
        await _http.post('${_one(id)}/messages', body: {'text': text}, timeout: HttpTransport.chatTimeout),
      ));

  Future<Topic> update(String id, {String? title, bool? archived}) async {
    final data = asObject(await _http.patch(_one(id), body: {
      if (title != null) 'title': title,
      if (archived != null) 'archived': archived,
    }));
    return Topic.fromJson(data['conversation'] as Map<String, dynamic>? ?? const {});
  }

  Future<void> delete(String id) async {
    await _http.delete(_one(id));
  }

  /// Confirms or cancels an action a topic answer is waiting on.
  Future<void> decide(String actionId, {required bool confirm}) async {
    await _http.post('$actionsPath/${Uri.encodeComponent(actionId)}/${confirm ? 'confirm' : 'cancel'}');
  }
}
