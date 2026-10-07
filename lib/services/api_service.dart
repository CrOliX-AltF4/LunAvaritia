import '../config/api_config.dart';
import '../models/alert.dart';
import '../models/assistant_identity.dart';
import '../models/digest.dart';
import 'backend_client.dart';
import 'http_transport.dart';
import 'inbox_api.dart';
import 'validation_api.dart';
import 'topic_api.dart';

/// The hub (Natsume Core) — its mobile façade under /api/mobile/*.
class ApiService extends BackendClient {
  ApiService(ApiConfig config) : this._(HttpTransport(config));

  ApiService._(this._http)
      : topics = TopicApi.hub(_http),
        inbox = InboxApi.hub(_http),
        validation = ValidationApi.hub(_http);

  final HttpTransport _http;

  @override
  final TopicApi topics;

  @override
  final InboxApi inbox;

  @override
  final ValidationApi validation;

  @override
  Future<AssistantIdentity> getIdentity() async =>
      AssistantIdentity.fromJson(asObject(await _http.get('/api/mobile/identity')));

  // ── The hub's own alerts ──────────────────────────────────────────────────

  /// Its copies of box items carry a `sourceKey`: left out, the box shows the items themselves.
  @override
  Future<List<Alert>> hubAlerts() async {
    final data = asObject(await _http.get('/api/mobile/alerts?limit=100'));
    final items = data['alerts'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>().where((a) => a['sourceKey'] == null).map(Alert.fromJson).toList();
  }

  @override
  Future<void> markHubAlertRead(String id) async {
    await _http.post('/api/mobile/alerts/${Uri.encodeComponent(id)}/read', body: const {});
  }

  @override
  Future<Digest> getDigest() async {
    // /api/mobile/digest, not /api/proxy/acedia/digest — the latter isn't under /api/mobile/*,
    // so a MOBILE_API_KEY-only caller (no panel session) got a silent 401 on it.
    return Digest.fromJson(asObject(await _http.get('/api/mobile/digest', timeout: HttpTransport.chatTimeout)));
  }

  // ── Push token ────────────────────────────────────────────────────────────

  @override
  Future<void> registerPushToken(String token) async {
    await _http.post('/api/mobile/push-token', body: {'token': token});
  }
}
