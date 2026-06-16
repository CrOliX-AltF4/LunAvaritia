import 'package:shared_preferences/shared_preferences.dart';

const _keyBaseUrl = 'server_base_url';
const _keyToken = 'server_token';

const defaultBaseUrl = 'http://192.168.1.x:3333';

class ApiConfig {
  ApiConfig._({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  static Future<ApiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ApiConfig._(
      baseUrl: prefs.getString(_keyBaseUrl) ?? defaultBaseUrl,
      token: prefs.getString(_keyToken) ?? '',
    );
  }

  static Future<void> save({required String baseUrl, required String token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, baseUrl);
    await prefs.setString(_keyToken, token);
  }

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}
