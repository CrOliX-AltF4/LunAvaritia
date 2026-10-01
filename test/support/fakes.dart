import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/models/alert.dart';
import 'package:lunavaritia/models/assistant_identity.dart';
import 'package:lunavaritia/models/topic.dart';
import 'package:lunavaritia/services/backend_client.dart';
import 'package:lunavaritia/services/http_transport.dart';
import 'package:lunavaritia/services/topic_api.dart';
import 'package:lunavaritia/services/update_checker.dart';

/// Shared test doubles: a backend that keeps topics in memory, answers turns with what a test sets, and records
/// every call — so widget tests exercise the real providers and screens without a network.

DateTime at(int minutesAgo, {DateTime? now}) => (now ?? DateTime.now()).subtract(Duration(minutes: minutesAgo));

Topic topic(String id, String title, {DateTime? updatedAt, bool archived = false, int messageCount = 2}) => Topic(
      id: id,
      title: title,
      createdAt: updatedAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      archived: archived,
      messageCount: messageCount,
    );

TopicMessage userMessage(String id, String text, {DateTime? when, String? about}) =>
    TopicMessage(id: id, role: TopicRole.user, text: text, at: when ?? DateTime.now(), about: about);

TopicMessage answer(String id, String text, {DateTime? when, AgentOutcome? agent, bool external = false}) =>
    TopicMessage(id: id, role: TopicRole.assistant, text: text, at: when ?? DateTime.now(), agent: agent, external: external);

class FakeTopicApi extends TopicApi {
  FakeTopicApi() : super(HttpTransport(ApiConfig.forTest(baseUrl: 'http://fake')), topicsPath: '/t', actionsPath: '/a');

  List<Topic> active = [];
  List<Topic> archivedTopics = [];
  final Map<String, List<TopicMessage>> messages = {};

  /// The answer to the next turn (open or send). Null: the turn fails with [turnError].
  TopicMessage? nextAnswer;
  BackendError turnError = BackendError(BackendErrorKind.timeout);

  /// When a turn fails, the server still stored the user's message (it does when only the answer failed).
  bool keepsFailedMessage = false;
  Object? decideError;

  final List<(String, String?)> opened = [];
  final List<(String, String)> sent = [];
  final List<(String, bool)> decisions = [];
  final List<String> deleted = [];
  int _ids = 0;

  String _id(String prefix) => '$prefix${++_ids}';

  @override
  Future<List<Topic>> list({bool archived = false}) async => archived ? archivedTopics : active;

  @override
  Future<TurnResult> open(String text, {String? aboutKey}) async {
    opened.add((text, aboutKey));
    final t = topic(_id('t'), text.length > 30 ? text.substring(0, 30) : text);
    final user = userMessage(_id('m'), text, about: aboutKey);
    final reply = nextAnswer;
    if (reply == null) throw turnError;
    active = [t, ...active];
    messages[t.id] = [user, reply];
    return TurnResult(topic: t, userMessage: user, message: reply);
  }

  @override
  Future<TopicPage> page(String id, {String? before, int limit = 30}) async {
    final all = messages[id] ?? const [];
    final end = before == null ? all.length : all.indexWhere((m) => m.id == before);
    final start = (end - limit).clamp(0, end);
    final t = [...active, ...archivedTopics].firstWhere((t) => t.id == id, orElse: () => topic(id, 'Sujet'));
    return TopicPage(topic: t, messages: all.sublist(start, end), hasMore: start > 0);
  }

  @override
  Future<TurnResult> send(String id, String text) async {
    sent.add((id, text));
    final user = userMessage(_id('m'), text);
    final reply = nextAnswer;
    if (reply == null) {
      if (keepsFailedMessage) messages[id] = [...?messages[id], user];
      throw turnError;
    }
    messages[id] = [...?messages[id], user, reply];
    final t = topic(id, active.firstWhere((t) => t.id == id, orElse: () => topic(id, 'Sujet')).title);
    return TurnResult(topic: t, userMessage: user, message: reply);
  }

  @override
  Future<Topic> update(String id, {String? title, bool? archived}) async {
    final all = [...active, ...archivedTopics];
    final old = all.firstWhere((t) => t.id == id);
    final updated = topic(id, title ?? old.title, archived: archived ?? old.archived, updatedAt: old.updatedAt);
    active = [for (final t in active) if (t.id != id) t, if (!updated.archived) updated];
    archivedTopics = [for (final t in archivedTopics) if (t.id != id) t, if (updated.archived) updated];
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    active = [for (final t in active) if (t.id != id) t];
  }

  @override
  Future<void> decide(String actionId, {required bool confirm}) async {
    decisions.add((actionId, confirm));
    if (decideError != null) throw decideError!;
  }
}

class FakeBackend extends BackendClient {
  FakeBackend({List<Alert>? alerts, this.digest = '', this.digestError, AssistantIdentity? identity})
      : alerts = alerts ?? [],
        identity = identity ?? const AssistantIdentity(name: 'Natsume', isCompanion: true);

  final List<Alert> alerts;
  final String digest;
  final Object? digestError;
  final AssistantIdentity identity;

  @override
  final FakeTopicApi topics = FakeTopicApi();

  @override
  Future<AssistantIdentity> getIdentity() async => identity;

  @override
  Future<List<Alert>> getAlerts({int limit = 50, int offset = 0, bool? unread, String? source, String? priority}) async =>
      alerts;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<String> getDigest() async {
    if (digestError != null) throw digestError!;
    return digest;
  }

  @override
  Future<void> registerPushToken(String token) async {}
}

/// Answers a fixed status — the real checker would ask GitHub.
class FakeUpdateChecker extends UpdateChecker {
  FakeUpdateChecker(this.status);
  final UpdateStatus status;
  int calls = 0;

  @override
  Future<UpdateStatus> check() async {
    calls++;
    return status;
  }
}
