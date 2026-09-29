import '../config/api_config.dart';
import '../models/alert.dart';
import '../models/chat_message.dart';
import '../models/natsume_status.dart';
import 'backend_client.dart';
import 'http_transport.dart';

/// The hub (Natsume Core) — its mobile façade under /api/mobile/*.
class ApiService extends BackendClient {
  ApiService(ApiConfig config) : _http = HttpTransport(config);

  final HttpTransport _http;

  // ── Chat ──────────────────────────────────────────────────────────────────

  @override
  Future<ChatMessage> sendChat(String text) async {
    final data = asObject(
      await _http.post('/api/mobile/chat', body: {'text': text}, timeout: HttpTransport.chatTimeout),
    );
    return ChatMessage.fromJson({'role': 'natsume', ...data});
  }

  @override
  Future<NatsumeStatus> getStatus() async {
    return NatsumeStatus.fromJson(asObject(await _http.get('/api/mobile/status')));
  }

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
