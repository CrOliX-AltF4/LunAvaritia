import 'package:flutter/foundation.dart';

import '../models/planning.dart';
import '../services/backend_client.dart';

/// The Planning screen's four views (maquette du 2026-10-17).
enum PlanningView { today, week, tasks, late }

/// The planning on the phone: LunAcedia holds it, « Fait » acts at Google Tasks and the screen adopts what the source
/// answered — a task is shown done only once LunAcedia said it is.
class PlanningController extends ChangeNotifier {
  PlanningController(this._api, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final BackendClient _api;
  final DateTime Function() _now;

  PlanningSnapshot? snapshot;
  PlanningView view = PlanningView.today;
  bool loading = false;
  String? error;

  /// The day « Aujourd'hui » shows — today, or the day touched in « Semaine ».
  DateTime? _day;

  DateTime get today {
    final n = _now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get day => _day ?? today;

  /// Today and the six days after.
  List<DateTime> get week => [for (var i = 0; i < 7; i++) DateTime(today.year, today.month, today.day + i)];

  int get lateCount => snapshot?.late(today).length ?? 0;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      snapshot = await _api.planning.snapshot();
      error = null;
    } on BackendError catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Erreur inattendue : $e';
    }
    loading = false;
    notifyListeners();
  }

  void show(PlanningView v) {
    view = v;
    if (v == PlanningView.today) _day = null;
    notifyListeners();
  }

  /// « Semaine » → one day's « Aujourd'hui ».
  void openDay(DateTime d) {
    _day = DateTime(d.year, d.month, d.day);
    view = PlanningView.today;
    notifyListeners();
  }

  /// Null when done; otherwise why it was not — the task then stays open.
  Future<String?> done(PlanningTask task) async {
    try {
      await _api.planning.done(task.id);
    } on BackendError catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur inattendue : $e';
    }
    final snap = snapshot;
    if (snap != null) snapshot = snap.withTask(task.completed());
    notifyListeners();
    return null;
  }
}
