import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant_identity.dart';

const _keyIdentity = 'assistant_identity';

/// The last identity the server gave (ADR-020 D2) — so the chat shows the right name at launch, before the
/// server has answered, and even out of reach.
class IdentityStore {
  const IdentityStore();

  Future<AssistantIdentity?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyIdentity);
    if (raw == null) return null;
    try {
      return AssistantIdentity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AssistantIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIdentity, jsonEncode(identity.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIdentity);
  }
}
