import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/assistant_identity.dart';
import '../services/backend_client.dart';
import '../services/identity_store.dart';

/// Who answers, as the server last said — cached, so the right name shows before the network answers.
class IdentityProvider extends ChangeNotifier {
  IdentityProvider(this._api, {IdentityStore store = const IdentityStore()}) : _store = store {
    unawaited(_loadCached());
  }

  final BackendClient _api;
  final IdentityStore _store;

  AssistantIdentity identity = AssistantIdentity.unknown;

  Future<void> _loadCached() async {
    final cached = await _store.load();
    if (cached == null) return;
    identity = cached;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      identity = await _api.getIdentity();
      unawaited(_store.save(identity));
      notifyListeners();
    } catch (_) {
      // keep the cached name — a failed refresh is not worth a banner
    }
  }
}
