import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The product is LunAcedia + this app (ADR-008). Wiring to a hub (the Natsume Core) is an advanced, optional
// setting — not a mode every user has to pick (ADR-020 D2, live check C20).
const _keyAcediaUrl = 'acedia_url';
const _keyAcediaToken = 'acedia_token';
const _keyHubUrl = 'hub_url';
const _keyHubToken = 'hub_token';

// Before ADR-020: one address + one token + a visible mode switch.
const _legacyKeyBaseUrl = 'server_base_url';
const _legacyKeyToken = 'server_token';
const _legacyKeyBackendMode = 'backend_mode';

const _secureStorage = FlutterSecureStorage();

class ApiConfig {
  ApiConfig._({
    required this.acediaUrl,
    required this.acediaToken,
    required this.hubUrl,
    required this.hubToken,
  });

  /// Test-only constructor — skips SharedPreferences/secure storage entirely. `backendMode: 'natsume'` puts the
  /// address behind the hub, anything else behind LunAcedia (the shape the tests were written against).
  @visibleForTesting
  factory ApiConfig.forTest({
    required String baseUrl,
    String token = '',
    String backendMode = 'lunacedia',
  }) =>
      backendMode == 'natsume'
          ? ApiConfig._(acediaUrl: '', acediaToken: '', hubUrl: baseUrl, hubToken: token)
          : ApiConfig._(acediaUrl: baseUrl, acediaToken: token, hubUrl: '', hubToken: '');

  /// LunAcedia's own address — the standalone product.
  final String acediaUrl;
  final String acediaToken;

  /// The hub's address (Natsume Core). Empty = not wired: the app talks to LunAcedia directly.
  final String hubUrl;
  final String hubToken;

  /// Wired to a hub: every call goes to the hub (hub-and-spoke — the app never reaches LunAcedia directly then).
  bool get wired => hubUrl.trim().isNotEmpty;

  /// 'natsume' when wired, else 'lunacedia' — which client talks to the server.
  String get backendMode => wired ? 'natsume' : 'lunacedia';

  /// The address and token of the server the app talks to right now.
  String get baseUrl => wired ? hubUrl.trim() : acediaUrl.trim();
  String get token => wired ? hubToken : acediaToken;

  static Future<ApiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacy(prefs);
    return ApiConfig._(
      acediaUrl: prefs.getString(_keyAcediaUrl) ?? '',
      acediaToken: await _secureStorage.read(key: _keyAcediaToken) ?? '',
      hubUrl: prefs.getString(_keyHubUrl) ?? '',
      hubToken: await _secureStorage.read(key: _keyHubToken) ?? '',
    );
  }

  /// One-time move from the single-address layout: in 'natsume' mode the saved address was the hub's, otherwise
  /// LunAcedia's. The old plaintext token (even older layout) goes to secure storage the same way.
  static Future<void> _migrateLegacy(SharedPreferences prefs) async {
    final legacyUrl = prefs.getString(_legacyKeyBaseUrl);
    if (legacyUrl == null) return;
    final wasHub = prefs.getString(_legacyKeyBackendMode) == 'natsume';
    final plaintextToken = prefs.getString(_legacyKeyToken);
    final token = (plaintextToken != null && plaintextToken.isNotEmpty)
        ? plaintextToken
        : await _secureStorage.read(key: _legacyKeyToken) ?? '';
    await prefs.setString(wasHub ? _keyHubUrl : _keyAcediaUrl, legacyUrl);
    if (token.isNotEmpty) await _secureStorage.write(key: wasHub ? _keyHubToken : _keyAcediaToken, value: token);
    await prefs.remove(_legacyKeyBaseUrl);
    await prefs.remove(_legacyKeyToken);
    await prefs.remove(_legacyKeyBackendMode);
    await _secureStorage.delete(key: _legacyKeyToken);
  }

  static Future<void> save({
    required String acediaUrl,
    required String acediaToken,
    required String hubUrl,
    required String hubToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAcediaUrl, acediaUrl.trim());
    await prefs.setString(_keyHubUrl, hubUrl.trim());
    await _secureStorage.write(key: _keyAcediaToken, value: acediaToken.trim());
    await _secureStorage.write(key: _keyHubToken, value: hubToken.trim());
  }

  /// A config built from the settings form, before saving — for "Tester la connexion".
  static ApiConfig fromForm({
    required String acediaUrl,
    required String acediaToken,
    required String hubUrl,
    required String hubToken,
  }) =>
      ApiConfig._(acediaUrl: acediaUrl, acediaToken: acediaToken, hubUrl: hubUrl, hubToken: hubToken);

  /// The same phone talking to LunAcedia directly — what it was before it was wired to a hub.
  ApiConfig get standalone => ApiConfig._(acediaUrl: acediaUrl, acediaToken: acediaToken, hubUrl: '', hubToken: '');

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
}
