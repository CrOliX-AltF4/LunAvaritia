import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/alert.dart';
import '../models/chat_message.dart';
import '../models/natsume_status.dart';
import 'backend_client.dart';

class LunAcediaClient extends BackendClient {
  LunAcediaClient(this._config);

  final ApiConfig _config;

  Uri _uri(String path) => Uri.parse('${_config.baseUrl}$path');

  // ── Chat ──────────────────────────────────────────────────────────────────

  @override
  Future<ChatMessage> sendChat(String text) async {
    final resp = await http.post(
      _uri('/api/chat'),
      headers: _config.headers,
      body: jsonEncode({'text': text}),
    );
    if (resp.statusCode >= 400) throw ApiException(resp.statusCode, resp.body);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return ChatMessage(
      role: MessageRole.natsume,
      text: data['response'] as String? ?? '',
      ts: DateTime.now(),
    );
  }

  // LunAcedia has no companion status concept
  @override
  Future<NatsumeStatus> getStatus() async => NatsumeStatus.empty;

  // ── Events → Alerts ───────────────────────────────────────────────────────

  @override
  Future<List<Alert>> getAlerts({int limit = 50, int offset = 0, bool? unread}) async {
    final resp = await http.get(
      _uri('/api/events?limit=$limit&offset=$offset'),
      headers: _config.headers,
    );
    if (resp.statusCode >= 400) throw ApiException(resp.statusCode, resp.body);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = data['events'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>().map(_eventToAlert).toList();
  }

  Alert _eventToAlert(Map<String, dynamic> e) => Alert.fromJson({
        'id': e['dedupeKey'],
        'type': e['type'],
        'title': e['title'],
        'priority': e['priority'],
        'ts': e['ts'],
        'read': false,
        'body': e['body'],
        'url': e['url'],
      });

  // LunAcedia has no server-side read state — silently ignored
  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  // ── Push token ────────────────────────────────────────────────────────────

  @override
  Future<void> registerPushToken(String token) async {
    final resp = await http.post(
      _uri('/api/devices/push-token'),
      headers: _config.headers,
      body: jsonEncode({'token': token}),
    );
    if (resp.statusCode >= 400) throw ApiException(resp.statusCode, resp.body);
  }
}
