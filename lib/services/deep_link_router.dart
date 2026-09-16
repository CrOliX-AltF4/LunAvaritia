import 'package:flutter/foundation.dart';

/// Mirrors MainShell's tab order — kept here so PushService doesn't need to import
/// screen-layer code just to know "alerts is tab 1".
enum AppTab { chat, alerts, settings }

/// Global, minimal cross-cutting channel for "switch to this tab" requests that originate
/// outside the widget tree — a tapped push notification, today the only source. MainShell
/// listens; whoever decided a tab switch is needed (PushService) writes.
///
/// Deliberately not a full routing/GoRouter setup: this app has exactly 3 flat tabs, no
/// nested/stacked routes worth addressing individually (LunAvaritia gap #3 — tapping a push
/// notification used to do nothing at all: no onMessageOpenedApp/getInitialMessage handler
/// existed, so the app just opened to whatever tab it last had, notification content
/// unreachable).
class DeepLinkRouter extends ChangeNotifier {
  DeepLinkRouter._();
  static final instance = DeepLinkRouter._();

  AppTab? _pending;
  AppTab? get pending => _pending;

  void requestTab(AppTab tab) {
    _pending = tab;
    notifyListeners();
  }

  /// Called by MainShell once it has acted on the pending request.
  void consume() {
    _pending = null;
  }
}

/// Both backends' FcmSender (LunAcedia's and Natsume's) only ever push alert-shaped content
/// today (email/calendar/github/system notifications) — there is no other kind of push in
/// this app, so every tap routes to the same place regardless of backendMode's differing
/// payload shape (`alertId`+`source` vs `type`+`source`+`dedupeKey`+`priority`). Kept as its
/// own function rather than inlined so the "there's only one destination today" fact is a
/// single, greppable place to revisit if that ever changes.
AppTab resolveDeepLinkTarget(Map<String, dynamic> data) => AppTab.alerts;
