import '../models/alert.dart';
import '../models/chat_message.dart';
import '../models/natsume_status.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ApiException($statusCode): $message';
}

abstract class BackendClient {
  Future<ChatMessage> sendChat(String text);
  Future<NatsumeStatus> getStatus();
  Future<List<Alert>> getAlerts({int limit = 50, int offset = 0, bool? unread});
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> registerPushToken(String token);
}
