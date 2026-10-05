import 'package:flutter/foundation.dart';

/// Where a tapped notification leads (ADR-020 §5.10 M4c): the box item it announces, read in full — or the box when the
/// notification is about nothing in it (a hub alert, a spend alert).
class DeepLinkTarget {
  const DeepLinkTarget.box({this.boxKey});

  /// The box item; null opens the box itself.
  final String? boxKey;
}

/// Global, minimal channel for "go there" requests that originate outside the widget tree — a tapped push
/// notification, today the only source. MainShell listens; PushService writes.
///
/// Deliberately not a full routing setup: the app has one screen at a time and a drawer (DA1), nothing stacked worth
/// addressing individually.
class DeepLinkRouter extends ChangeNotifier {
  DeepLinkRouter._();
  static final instance = DeepLinkRouter._();

  DeepLinkTarget? _pending;

  /// Bumped when a notification arrives with the app open: the box may have changed, worth reading again.
  final boxNudges = ValueNotifier<int>(0);

  void nudgeBox() => boxNudges.value++;
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

/// LunAcedia's push carries the item's `dedupeKey`; the hub's carries `key` when its alert is about a box item.
DeepLinkTarget resolveDeepLinkTarget(Map<String, dynamic> data) {
  final key = data['key'] ?? data['dedupeKey'];
  return DeepLinkTarget.box(boxKey: key is String && key.isNotEmpty ? key : null);
}
