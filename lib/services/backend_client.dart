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
  Future<List<Alert>> getAlerts({
    int limit = 50,
    int offset = 0,
    bool? unread,
    String? source,
    String? priority,
  });
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<String> getDigest();
  Future<void> registerPushToken(String token);
}

/// The client for the saved configuration — the one place that picks a backend.
BackendClient buildBackendClient(ApiConfig config) =>
    config.backendMode == 'lunacedia' ? LunAcediaClient(config) : ApiService(config);
