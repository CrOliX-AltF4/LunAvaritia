import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import 'backend_client.dart';

/// Where the notifications of a server this phone left still have to be let go — kept until that server answers.
abstract class PendingReleaseStore {
  Future<ApiConfig?> read();
  Future<void> write(ApiConfig server);
  Future<void> clear();
}

/// The phone's own store: the old server's address and device token, in secure storage like every token.
class SecurePendingReleaseStore implements PendingReleaseStore {
  static const _key = 'push_release_pending';
  final _storage = const FlutterSecureStorage();

  @override
  Future<ApiConfig?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return ApiConfig.server(baseUrl: m['url'] as String, token: m['token'] as String, wired: m['wired'] as bool);
  }

  @override
  Future<void> write(ApiConfig server) => _storage.write(
        key: _key,
        value: jsonEncode({'url': server.baseUrl, 'token': server.token, 'wired': server.wired}),
      );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

Future<String?> _firebaseToken() async {
  try {
    return await FirebaseMessaging.instance.getToken();
  } catch (_) {
    return null;
  }
}

/// The phone's connection: which server it talks to — LunAcedia (standalone) or a hub (wired) — and where its
/// notifications come from. The one place that changes mode: the clients, the stream of changes and the notification
/// token follow it, without restarting the app.
///
/// Invariant: the notification token is registered with one server, the one the app talks to. A move registers it
/// with the new server first, then lets the old one go; a server out of reach is retried at the next start, never
/// forgotten — a phone that rang twice, or not at all, is what this replaces.
class ConnectionController extends ChangeNotifier {
  ConnectionController({
    required ApiConfig config,
    Future<void> Function(ApiConfig config)? persist,
    PendingReleaseStore? pending,
    Future<String?> Function()? pushToken,
    BackendClient Function(ApiConfig config)? clientFor,
  })  : _config = config,
        _persist = persist ?? ApiConfig.persist,
        _pending = pending ?? SecurePendingReleaseStore(),
        _pushToken = pushToken ?? _firebaseToken,
        _clientFor = clientFor ?? buildBackendClient;

  static Future<ConnectionController> load() async => ConnectionController(config: await ApiConfig.load());

  ApiConfig _config;
  final Future<void> Function(ApiConfig config) _persist;
  final PendingReleaseStore _pending;
  final Future<String?> Function() _pushToken;
  final BackendClient Function(ApiConfig config) _clientFor;
  bool _releasePending = false;

  ApiConfig get config => _config;

  /// Wired to a hub: it sends the notifications. Standalone: LunAcedia does.
  bool get wired => _config.wired;

  /// A server this phone left has not let its token go yet (out of reach) — retried at the next start.
  bool get releasePending => _releasePending;

  /// Applies a new connection at once — clients and views follow — then moves the notifications.
  Future<void> apply(ApiConfig next) async {
    final previous = _config;
    await _persist(next);
    _config = next;
    notifyListeners();
    final moved = previous.baseUrl.trim() != next.baseUrl.trim() || previous.wired != next.wired;
    if (moved && previous.baseUrl.trim().isNotEmpty) await _pending.write(previous);
    await settle();
  }

  /// Registers the token with the server the app talks to; once that holds, the server it left lets it go.
  /// Called at every start and after each move: what failed before is retried here.
  Future<void> settle() async {
    if (!await registerToken()) {
      await _readPending();
      return;
    }
    final old = await _pending.read();
    if (old == null || _sameServer(old, _config)) {
      await _pending.clear();
      _setPending(false);
      return;
    }
    try {
      await _clientFor(old).unregisterPushToken();
      await _pending.clear();
      _setPending(false);
    } catch (_) {
      _setPending(true);
    }
  }

  /// Sends the token (the current one, or a renewed one) to the server the app talks to now — never a client built at
  /// launch. True when registered, or when there is nothing to register (no notifications on this phone).
  Future<bool> registerToken([String? renewed]) async {
    if (_config.baseUrl.trim().isEmpty) return false;
    final token = renewed ?? await _pushToken();
    if (token == null) return true;
    try {
      await _clientFor(_config).registerPushToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _readPending() async => _setPending(await _pending.read() != null);

  void _setPending(bool value) {
    if (_releasePending == value) return;
    _releasePending = value;
    notifyListeners();
  }

  static bool _sameServer(ApiConfig a, ApiConfig b) => a.baseUrl.trim() == b.baseUrl.trim() && a.wired == b.wired;
}
