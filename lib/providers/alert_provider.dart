import 'package:flutter/foundation.dart';
import '../models/alert.dart';
import '../services/backend_client.dart';

enum AlertFilter { all, urgent, email, calendar, tasks }

class AlertProvider extends ChangeNotifier {
  AlertProvider(this._api);

  final BackendClient _api;

  List<Alert> _alerts = [];
  AlertFilter filter = AlertFilter.all;
  bool loading = false;
  bool refreshing = false;
  String? error;

  List<Alert> get alerts {
    if (filter == AlertFilter.all) return _alerts;
    return _alerts.where((a) {
      return switch (filter) {
        AlertFilter.urgent   => a.priority == AlertPriority.urgent,
        AlertFilter.email    => a.source == AlertSource.email,
        AlertFilter.calendar => a.source == AlertSource.calendar,
        AlertFilter.tasks    => a.source == AlertSource.tasks,
        AlertFilter.all      => true,
      };
    }).toList();
  }

  int get unreadCount => _alerts.where((a) => !a.read).length;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _alerts = await _api.getAlerts();
    } on ApiException catch (e) {
      error = 'Erreur ${e.statusCode}';
    } catch (_) {
      error = 'Connexion impossible';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    refreshing = true;
    notifyListeners();
    try {
      _alerts = await _api.getAlerts();
      error = null;
    } catch (_) {} finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String alertId) async {
    try {
      await _api.markRead(alertId);
      final idx = _alerts.indexWhere((a) => a.id == alertId);
      if (idx != -1) {
        _alerts[idx] = _alerts[idx].copyWith(read: true);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllRead();
      _alerts = _alerts.map((a) => a.copyWith(read: true)).toList();
      notifyListeners();
    } catch (_) {}
  }

  void setFilter(AlertFilter f) {
    filter = f;
    notifyListeners();
  }

  Future<String> fetchDigest() async {
    return _api.getDigest();
  }
}
