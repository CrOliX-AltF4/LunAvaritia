import 'package:flutter/foundation.dart';

import '../services/backend_client.dart';
import '../services/validation_api.dart';

/// « À valider » (ADR-020 §5.11 M5d): what waits for Master — the hub's memory proposals (wired) and LunAcedia's pending
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
    try {
      writes = await _api.validation.actions();
      error = null;
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
  }

  /// Null when done; otherwise why it was not.
  Future<String?> decide(PendingWrite w, {required bool confirm}) => _run(() async {
        await _api.validation.decide(w.id, confirm: confirm);
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
