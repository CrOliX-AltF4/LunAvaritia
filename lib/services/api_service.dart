import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
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

class ApiService {
  ApiService(this._config);

  final ApiConfig _config;

  Uri _uri(String path) => Uri.parse('${_config.baseUrl}$path');

  Future<Map<String, dynamic>> _get(String path) async {
    final resp = await http.get(_uri(path), headers: _config.headers);
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, resp.body);
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await http.post(
      _uri(path),
      headers: _config.headers,
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, resp.body);
    }
    if (resp.body.isEmpty || resp.statusCode == 204) return {};
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<ChatMessage> sendChat(String text) async {
    final data = await _post('/api/mobile/chat', {'text': text});
    return ChatMessage.fromJson({'role': 'natsume', ...data});
  }

  Future<NatsumeStatus> getStatus() async {
    final data = await _get('/api/mobile/status');
    return NatsumeStatus.fromJson(data);
  }

  // ── Alerts ────────────────────────────────────────────────────────────────

  Future<List<Alert>> getAlerts({int limit = 50, int offset = 0, bool? unread}) async {
    final q = StringBuffer('/api/mobile/alerts?limit=$limit&offset=$offset');
    if (unread == true) q.write('&unread=true');
    final data = await _get(q.toString());
    final items = data['alerts'] as List<dynamic>? ?? [];
    return items
        .cast<Map<String, dynamic>>()
        .map(Alert.fromJson)
        .toList();
  }

  Future<void> markRead(String alertId) async {
    await _post('/api/mobile/alerts/$alertId/read', {});
  }

  Future<void> markAllRead() async {
    await _post('/api/mobile/alerts/read-all', {});
  }

  // ── Push token ────────────────────────────────────────────────────────────

  Future<void> registerPushToken(String token) async {
    await _post('/api/mobile/push-token', {'token': token});
  }
}
