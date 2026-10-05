import '../config/api_config.dart';
import '../models/alert.dart';
import '../models/assistant_identity.dart';
import 'api_service.dart';
import 'inbox_api.dart';
import 'lunacedia_client.dart';
import 'topic_api.dart';

export 'backend_error.dart';

abstract class BackendClient {
  /// Topics — the conversations, stored by the server (ADR-020 amendment 1). The app keeps no history of its own.
  TopicApi get topics;

  /// The box — LunAcedia's, gestures at the source (ADR-018, ADR-020 §5.10).
  InboxApi get inbox;

  /// Who answers — name and whether it is the hub's companion (ADR-020 D2). Also the connection test.
  Future<AssistantIdentity> getIdentity();
  /// The hub's own alerts (system, spend, Discord) — never its copies of box items. Empty on LunAcedia.
  Future<List<Alert>> hubAlerts();
  Future<void> markHubAlertRead(String id);
  Future<String> getDigest();
  Future<void> registerPushToken(String token);
}

/// The client for the saved configuration — the one place that picks a backend.
BackendClient buildBackendClient(ApiConfig config) =>
    config.backendMode == 'lunacedia' ? LunAcediaClient(config) : ApiService(config);
