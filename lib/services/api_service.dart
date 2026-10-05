import '../config/api_config.dart';
import '../models/alert.dart';
import '../models/assistant_identity.dart';
import 'backend_client.dart';
import 'http_transport.dart';
import 'inbox_api.dart';
import 'topic_api.dart';

/// The hub (Natsume Core) — its mobile façade under /api/mobile/*.
class ApiService extends BackendClient {
  ApiService(ApiConfig config) : this._(HttpTransport(config));

  ApiService._(this._http)
      : topics = TopicApi.hub(_http),
        inbox = InboxApi.hub(_http);

  final HttpTransport _http;

  @override
  final TopicApi topics;

  @override
  final InboxApi inbox;

  @override
  Future<AssistantIdentity> getIdentity() async =>
      AssistantIdentity.fromJson(asObject(await _http.get('/api/mobile/identity')));

  // ── Alerts ────────────────────────────────────────────────────────────────

  @override
  Future<List<Alert>> getAlerts({
    int limit = 50,
    int offset = 0,
    bool? unread,
    String? source,
    String? priority,
  }) async {
    final q = StringBuffer('/api/mobile/alerts?limit=$limit&offset=$offset');
    if (unread == true) q.write('&unread=true');
    // source and priority filters not supported by the hub's mobile API — ignored
    final data = asObject(await _http.get(q.toString()));
    final items = data['alerts'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>().map(Alert.fromJson).toList();
  }

  @override
  Future<void> markRead(String id) async {
    await _http.post('/api/mobile/alerts/${Uri.encodeComponent(id)}/read', body: const {});
  }

  @override
  Future<void> markAllRead() async {
    await _http.post('/api/mobile/alerts/read-all', body: const {});
  }

  @override
  Future<String> getDigest() async {
    // /api/mobile/digest, not /api/proxy/acedia/digest — the latter isn't under /api/mobile/*,
    // so a MOBILE_API_KEY-only caller (no panel session) got a silent 401 on it (ADR-013 I4).
    final data = asObject(await _http.get('/api/mobile/digest', timeout: HttpTransport.chatTimeout));
    return data['response'] as String? ?? '';
  }

  // ── Push token ────────────────────────────────────────────────────────────

  @override
  Future<void> registerPushToken(String token) async {
    await _http.post('/api/mobile/push-token', body: {'token': token});
  }
}
