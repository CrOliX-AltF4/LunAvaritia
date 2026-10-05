import '../models/box_item.dart';
import 'http_transport.dart';

/// The box contract (ADR-018, ADR-020 §5.10) — the same paths and shapes on LunAcedia (standalone) and on the hub
/// (wired), only the prefix changes. Every gesture acts at the source and the answer says what changed.
class InboxApi {
  InboxApi(this._http, {required this.path});

  /// LunAcedia: talks to it directly.
  InboxApi.lunacedia(HttpTransport http) : this(http, path: '/api/inbox');

  /// The hub: the Core relays to LunAcedia as is (hub-and-spoke).
  InboxApi.hub(HttpTransport http) : this(http, path: '/api/mobile/inbox');

  final HttpTransport _http;
  final String path;

  Future<BoxPage> list() async {
    final data = asObject(await _http.get(path));
    return BoxPage(
      items: [
        for (final e in (data['items'] as List<dynamic>? ?? const []))
          if (e is Map<String, dynamic>) BoxItem.fromJson(e),
      ],
      unread: data['unread'] as int? ?? 0,
    );
  }

  Future<GestureResult> gesture(String key, BoxGesture gesture) async => GestureResult.fromJson(
        asObject(await _http.post('$path/${Uri.encodeComponent(key)}/${gesture.name}')),
      );

  /// Gmail's trash, most recent first.
  Future<List<TrashItem>> trash() async {
    final data = asObject(await _http.get('$path/trash'));
    return [
      for (final t in (data['items'] as List<dynamic>? ?? const []))
        if (t is Map<String, dynamic>) TrashItem.fromJson(t),
    ];
  }

  /// Back to the inbox at the source; LunAcedia collects it again at its next pass.
  Future<void> restore(String messageId) async {
    await _http.post('$path/trash/${Uri.encodeComponent(messageId)}/restore');
  }
}
