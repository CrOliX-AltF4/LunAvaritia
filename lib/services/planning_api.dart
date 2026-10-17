import '../models/planning.dart';
import 'http_transport.dart';

/// The planning contract — the same paths and shapes on LunAcedia (standalone) and on the hub (wired), only the
/// prefix changes. LunAcedia holds the planning; the hub relays it as is.
class PlanningApi {
  PlanningApi(this._http, {required this.path});

  PlanningApi.lunacedia(HttpTransport http) : this(http, path: '/api/planning');

  PlanningApi.hub(HttpTransport http) : this(http, path: '/api/mobile/planning');

  final HttpTransport _http;
  final String path;

  Future<PlanningSnapshot> snapshot() async => PlanningSnapshot.fromJson(asObject(await _http.get(path)));

  /// « Fait »: completed at Google Tasks at once — Master's hand, not a write that waits for a confirmation.
  Future<void> done(String taskId) async {
    await _http.post('$path/tasks/${Uri.encodeComponent(taskId)}/done');
  }
}
