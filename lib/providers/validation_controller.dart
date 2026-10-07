import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/backend_client.dart';
import '../services/notification_tray.dart';
import '../services/validation_api.dart';

/// « À valider »: what waits for Master — the hub's memory proposals (wired) and LunAcedia's pending
/// writes. Each decision goes to its server, which answers; a refusal keeps the item and says why.
class ValidationController extends ChangeNotifier {
  ValidationController(this._api);

  final BackendClient _api;

  List<PendingWrite> writes = [];
  List<MemoryProposal> proposals = [];
  bool loaded = false;
  String? error;

  bool get hasMemory => _api.validation.hasMemory;

  /// What the drawer counts.
  int get count => writes.length + proposals.length;

  Future<void> load() async {
    var read = false;
    try {
      writes = await _api.validation.actions();
      error = null;
      read = true;
    } on BackendError catch (e) {
      error = e.message;
    }
    // Apart: proposals that fail to load never hide the writes.
    try {
      proposals = await _api.validation.proposals();
    } catch (_) {
      proposals = [];
    }
    loaded = true;
    notifyListeners();
    // An action no longer waiting — decided elsewhere, expired — takes its notification down.
    if (read) {
      final waiting = {for (final w in writes) 'action-${w.id}'};
      final tray = NotificationTray.instance;
      for (final tag in await tray.shownTags()) {
        if (tag.startsWith('action-') && !waiting.contains(tag)) await tray.dismiss(tag);
      }
    }
  }

  /// Null when done; otherwise why it was not.
  Future<String?> decide(PendingWrite w, {required bool confirm}) => _run(() async {
        await _api.validation.decide(w.id, confirm: confirm);
        unawaited(NotificationTray.instance.dismiss('action-${w.id}'));
        writes = writes.where((x) => x.id != w.id).toList();
      });

  /// Kept — in Master's own words when [text] is given (« Modifier »).
  Future<String?> approve(MemoryProposal p, {String? text}) => _run(() async {
        await _api.validation.approve(p.id, text: text);
        proposals = proposals.where((x) => x.id != p.id).toList();
      });

  Future<String?> reject(MemoryProposal p) => _run(() async {
        await _api.validation.reject(p.id);
        proposals = proposals.where((x) => x.id != p.id).toList();
      });

  Future<String?> _run(Future<void> Function() step) async {
    try {
      await step();
      notifyListeners();
      return null;
    } on BackendError catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur inattendue : $e';
    }
  }
}
