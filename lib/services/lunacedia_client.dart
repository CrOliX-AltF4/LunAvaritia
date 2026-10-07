import '../config/api_config.dart';
import '../models/alert.dart';
import '../models/assistant_identity.dart';
import '../models/digest.dart';
import 'backend_client.dart';
import 'http_transport.dart';
import 'inbox_api.dart';
import 'validation_api.dart';
import 'topic_api.dart';

/// LunAcedia on its own (standalone mode).
class LunAcediaClient extends BackendClient {
  LunAcediaClient(ApiConfig config) : this._(HttpTransport(config));

  LunAcediaClient._(this._http)
      : topics = TopicApi.lunacedia(_http),
        inbox = InboxApi.lunacedia(_http),
        validation = ValidationApi.lunacedia(_http);

  final HttpTransport _http;

  @override
  final TopicApi topics;

  @override
  final InboxApi inbox;

  @override
  final ValidationApi validation;

  @override
  Future<AssistantIdentity> getIdentity() async =>
      AssistantIdentity.fromJson(asObject(await _http.get('/api/identity')));

  // ── No hub, no hub alerts ─────────────────────────────────────────────────

  @override
  Future<List<Alert>> hubAlerts() async => const [];

  @override
  Future<void> markHubAlertRead(String id) async {}

  @override
  Future<Digest> getDigest() async {
    return Digest.fromJson(asObject(await _http.get('/api/digest', timeout: HttpTransport.chatTimeout)));
  }

  // ── Push token ────────────────────────────────────────────────────────────

  @override
  Future<void> registerPushToken(String token) async {
    await _http.post('/api/devices/push-token', body: {'token': token});
  }

  /// Stops LunAcedia's notifications to this phone (its own token only, never another device's).
  Future<void> unregisterPushToken() async {
    await _http.delete('/api/devices/push-token');
  }
}
