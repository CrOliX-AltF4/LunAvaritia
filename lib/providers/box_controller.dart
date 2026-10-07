import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/alert.dart';
import '../models/box_item.dart';
import '../models/digest.dart';
import '../services/backend_client.dart';
import '../services/notification_tray.dart';

/// Chips of the box (DA1): every source, or one.
enum BoxFilter { all, email, calendar, github, tasks }

/// The box on the phone: LunAcedia holds it, every gesture acts at the source and the
/// list adopts what the source answered — nothing is removed on a guess. Wired, the hub's own alerts sit apart.
class BoxController extends ChangeNotifier {
  BoxController(this._api);

  final BackendClient _api;

  List<BoxItem> _items = [];
  List<Alert> _hubAlerts = [];
  BoxFilter filter = BoxFilter.all;
  bool loading = false;
  bool loaded = false;
  String? error;

  Iterable<BoxItem> get _shown => filter == BoxFilter.all ? _items : _items.where((i) => i.source.name == filter.name);

  /// Newest first, as LunAcedia sends them.
  List<BoxItem> get urgent => _shown.where((i) => i.priority == BoxPriority.urgent).toList();
  List<BoxItem> get rest => _shown.where((i) => i.priority != BoxPriority.urgent).toList();
  List<Alert> get hubAlerts => List.unmodifiable(_hubAlerts);

  /// Whatever the filter — what the drawer and the home screen count.
  int get unreadCount => _items.where((i) => !i.read).length;
  int get urgentUnreadCount => _items.where((i) => !i.read && i.priority == BoxPriority.urgent).length;

  BoxItem? byKey(String key) {
    for (final i in _items) {
      if (i.key == key) return i;
    }
    return null;
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      _items = (await _api.inbox.list()).items;
      error = null;
      _boxLoaded = true;
    } on BackendError catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Erreur inattendue : $e';
    }
    // Apart: a hub alert that fails to load never hides the box.
    try {
      _hubAlerts = await _api.hubAlerts();
    } catch (_) {
      _hubAlerts = [];
    }
    loading = false;
    loaded = true;
    notifyListeners();
    await _sweepTray();
  }

  bool _boxLoaded = false;

  /// Takes down the notifications whose object is settled — read or gone from the box, a hub alert read — whatever
  /// settled it (another device, the panel, the source itself). Actions are « À valider »'s to sweep.
  Future<void> _sweepTray() async {
    if (!_boxLoaded) return;
    final tray = NotificationTray.instance;
    for (final tag in await tray.shownTags()) {
      if (tag.startsWith('action-')) continue;
      if (tag.startsWith('alert-')) {
        final id = tag.substring('alert-'.length);
        if (_hubAlerts.any((a) => a.id == id && a.read)) await tray.dismiss(tag);
        continue;
      }
      final item = byKey(tag);
      if (item == null || item.read) await tray.dismiss(tag);
    }
  }

  void setFilter(BoxFilter f) {
    filter = f;
    notifyListeners();
  }

  /// Null when done; otherwise why it was not — the item then stays as it was.
  Future<String?> gesture(BoxItem item, BoxGesture gesture) async {
    try {
      _adopt(item.key, (await _api.inbox.gesture(item.key, gesture)).change);
      return null;
    } on BackendError catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur inattendue : $e';
    }
  }

  /// The full text; the item is read at the source from then on. Throws a [BackendError].
  Future<String> open(BoxItem item) async {
    final result = await _api.inbox.gesture(item.key, BoxGesture.open);
    _adopt(item.key, result.change);
    return result.body ?? item.body ?? '';
  }

  void _adopt(String key, BoxChange? change) {
    // Read or gone: its notification has nothing left to say.
    if (change == BoxChange.removed || change == BoxChange.read) unawaited(NotificationTray.instance.dismiss(key));
    switch (change) {
      case BoxChange.removed:
        _items = _items.where((i) => i.key != key).toList();
      case BoxChange.read || BoxChange.unread:
        _items = [for (final i in _items) i.key == key ? i.copyWith(read: change == BoxChange.read) : i];
      case null:
        return;
    }
    notifyListeners();
  }

  Future<TrashPage> trash({String? page}) => _api.inbox.trash(page: page);

  Future<void> restore(String messageId) => _api.inbox.restore(messageId);

  Future<void> markHubAlertRead(String id) async {
    await _api.markHubAlertRead(id);
    unawaited(NotificationTray.instance.dismiss('alert-$id'));
    _hubAlerts = [for (final a in _hubAlerts) a.id == id ? a.copyWith(read: true) : a];
    notifyListeners();
  }

  Future<Digest> fetchDigest() => _api.getDigest();
}
