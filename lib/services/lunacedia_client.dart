import '../config/api_config.dart';
import '../models/alert.dart';
import '../models/assistant_identity.dart';
import '../models/chat_message.dart';
import '../models/companion_status.dart';
import 'backend_client.dart';
import 'http_transport.dart';

/// Maps a raw LunAcedia event (GET /api/events) to the shared Alert model.
/// Top-level and pure so it's testable without any HTTP plumbing (ADR-013 I4).
Alert eventToAlert(Map<String, dynamic> e) => Alert.fromJson({
      'id': e['dedupeKey'],
      'type': e['type'],
      'title': e['title'],
      'priority': e['priority'],
      'ts': e['ts'],
      // LunAcedia's own read status, not hardcoded false — an already-read alert must not
      // come back as unread on the next fetch (ADR-013 I4, real bug found reading the code).
      'read': e['read'] ?? false,
      'body': e['body'],
      'url': e['url'],
    });

/// LunAcedia on its own (standalone mode).
class LunAcediaClient extends BackendClient {
  LunAcediaClient(ApiConfig config) : _http = HttpTransport(config);

  final HttpTransport _http;

  // ── Chat ──────────────────────────────────────────────────────────────────

  @override
  Future<ChatMessage> sendChat(String text) async {
    final data = asObject(
      await _http.post('/api/chat', body: {'text': text}, timeout: HttpTransport.chatTimeout),
    );
    return ChatMessage(
      role: MessageRole.assistant,
      text: data['response'] as String? ?? '',
      ts: DateTime.now(),
    );
  }

  @override
  Future<AssistantIdentity> getIdentity() async =>
      AssistantIdentity.fromJson(asObject(await _http.get('/api/identity')));

  // LunAcedia has no companion status concept
  @override
  Future<CompanionStatus> getStatus() async => CompanionStatus.empty;

  // ── Events → Alerts ───────────────────────────────────────────────────────

  @override
  Future<List<Alert>> getAlerts({
    int limit = 50,
    int offset = 0,
    bool? unread,
    String? source,
    String? priority,
  }) async {
    final q = StringBuffer('/api/events?limit=$limit&offset=$offset');
    if (unread == true) q.write('&unread=true');
    if (source != null) q.write('&source=$source');
    if (priority != null) q.write('&priority=$priority');
    final data = asObject(await _http.get(q.toString()));
    final items = data['events'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>().map(eventToAlert).toList();
  }

  @override
  Future<void> markRead(String id) async {
    await _http.post('/api/events/${Uri.encodeComponent(id)}/read');
  }

  @override
  Future<void> markAllRead() async {
    await _http.post('/api/events/read-all');
  }

  @override
  Future<String> getDigest() async {
    final data = asObject(await _http.get('/api/digest', timeout: HttpTransport.chatTimeout));
    return data['response'] as String? ?? '';
  }

  // ── Push token ────────────────────────────────────────────────────────────

  @override
  Future<void> registerPushToken(String token) async {
    await _http.post('/api/devices/push-token', body: {'token': token});
  }
}
