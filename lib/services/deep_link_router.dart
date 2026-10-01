import 'package:flutter/foundation.dart';

/// Where a tapped notification leads. Every push both servers send today announces an element of the box (a mail,
/// an event, a GitHub notification), so it opens the box; "Traiter" there opens a topic about it (ADR-020 S4).
enum DeepLinkTarget { box }

/// Global, minimal channel for "go there" requests that originate outside the widget tree — a tapped push
/// notification, today the only source. MainShell listens; PushService writes.
///
/// Deliberately not a full routing setup: the app has one screen at a time and a drawer (DA1), nothing stacked worth
/// addressing individually.
class DeepLinkRouter extends ChangeNotifier {
  DeepLinkRouter._();
  static final instance = DeepLinkRouter._();

  DeepLinkTarget? _pending;
  DeepLinkTarget? get pending => _pending;

  void request(DeepLinkTarget target) {
    _pending = target;
    notifyListeners();
  }

  /// Called by MainShell once it has acted on the pending request.
  void consume() {
    _pending = null;
  }
}

/// Both servers' pushes are box elements: LunAcedia sends `dedupeKey`, the hub `alertId` (+ `key` when the alert is
/// about a box item). Kept as its own function so "there is only one destination today" is one greppable place.
DeepLinkTarget resolveDeepLinkTarget(Map<String, dynamic> data) => DeepLinkTarget.box;
