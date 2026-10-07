import '../config/api_config.dart';
import '../models/alert.dart';
import '../models/assistant_identity.dart';
import '../models/digest.dart';
import 'api_service.dart';
import 'inbox_api.dart';
import 'validation_api.dart';
import 'lunacedia_client.dart';
import 'topic_api.dart';

export 'backend_error.dart';

abstract class BackendClient {
  /// Topics — the conversations, stored by the server. The app keeps no history of its own.
  TopicApi get topics;

  /// The box — LunAcedia's, gestures at the source.
  InboxApi get inbox;

  /// « À valider »: pending writes, and the hub's memory proposals.
  ValidationApi get validation;

  /// Who answers — name and whether it is the hub's companion. Also the connection test.
  Future<AssistantIdentity> getIdentity();
  /// The hub's own alerts (system, spend, Discord) — never its copies of box items. Empty on LunAcedia.
  Future<List<Alert>> hubAlerts();
  Future<void> markHubAlertRead(String id);
  /// What is still unread: the urgent items listed by LunAcedia, then the model's summary.
  Future<Digest> getDigest();
  Future<void> registerPushToken(String token);
}

/// The client for the saved configuration — the one place that picks a backend.
BackendClient buildBackendClient(ApiConfig config) =>
    config.backendMode == 'lunacedia' ? LunAcediaClient(config) : ApiService(config);
