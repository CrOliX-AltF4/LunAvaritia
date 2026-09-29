import '../config/api_config.dart';
import '../models/alert.dart';
import '../models/chat_message.dart';
import '../models/natsume_status.dart';
import 'api_service.dart';
import 'lunacedia_client.dart';

export 'backend_error.dart';

abstract class BackendClient {
  Future<ChatMessage> sendChat(String text);
  Future<NatsumeStatus> getStatus();
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
