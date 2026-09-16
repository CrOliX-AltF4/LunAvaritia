import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyBaseUrl = 'server_base_url';
const _keyToken = 'server_token';
const _keyBackendMode = 'backend_mode';

const defaultBaseUrl = 'http://192.168.1.x:3333';

const _secureStorage = FlutterSecureStorage();

class ApiConfig {
  ApiConfig._({required this.baseUrl, required this.token, required this.backendMode});

  final String baseUrl;
  final String token;

  /// 'lunacedia' (default) or 'natsume'
  final String backendMode;

  static Future<ApiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();

    // One-time migration: the token used to live in plaintext SharedPreferences. Move it
    // to secure storage and delete the plaintext copy so an existing install isn't left
    // with the secret in both places (or worse, only in the insecure one going forward).
    final legacyToken = prefs.getString(_keyToken);
    if (legacyToken != null) {
      if (legacyToken.isNotEmpty) await _secureStorage.write(key: _keyToken, value: legacyToken);
      await prefs.remove(_keyToken);
    }

    return ApiConfig._(
      baseUrl:     prefs.getString(_keyBaseUrl)     ?? defaultBaseUrl,
      token:       await _secureStorage.read(key: _keyToken) ?? '',
      backendMode: prefs.getString(_keyBackendMode) ?? 'lunacedia',
    );
  }

  static Future<void> save({
    required String baseUrl,
    required String token,
    String? backendMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, baseUrl);
    await _secureStorage.write(key: _keyToken, value: token);
    if (backendMode != null) {
      await prefs.setString(_keyBackendMode, backendMode);
    }
  }

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}
