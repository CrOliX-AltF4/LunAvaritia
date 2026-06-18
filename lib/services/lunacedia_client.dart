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
  Future<List<Alert>> getAlerts({
    int limit = 50,
    int offset = 0,
    bool? unread,
    String? source,
    String? priority,
  }) async {
    final q = StringBuffer('/api/events?limit=$limit&offset=$offset');
    if (unread == true) q.write('&unread=true');
    if (source != null) q.write('&source=$source');
    if (priority != null) q.write('&priority=$priority');
    final resp = await http.get(_uri(q.toString()), headers: _config.headers);
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

  @override
  Future<void> markRead(String id) async {
    final resp = await http.post(
      _uri('/api/events/$id/read'),
      headers: _config.headers,
    );
    if (resp.statusCode >= 400) throw ApiException(resp.statusCode, resp.body);
  }

  @override
  Future<void> markAllRead() async {
    final resp = await http.post(
      _uri('/api/events/read-all'),
      headers: _config.headers,
    );
    if (resp.statusCode >= 400) throw ApiException(resp.statusCode, resp.body);
  }

  @override
  Future<String> getDigest() async {
    final resp = await http.get(_uri('/api/digest'), headers: _config.headers);
    if (resp.statusCode >= 400) throw ApiException(resp.statusCode, resp.body);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['response'] as String? ?? '';
  }

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
