import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'backend_error.dart';

/// The one place the app talks HTTP: every call has a time limit and every failure becomes a
/// [BackendError] of a precise kind. Uses the top-level `http` functions so tests can swap the client
/// with `http.runWithClient`.
class HttpTransport {
  HttpTransport(this._config);

  final ApiConfig _config;

  /// Reads and small writes — a healthy server answers well within this.
  static const readTimeout = Duration(seconds: 12);

  /// A chat turn — the server may delegate to an agent that itself works for up to 20 s.
  static const chatTimeout = Duration(seconds: 75);

  Uri _uri(String path) {
    final base = _config.baseUrl.trim();
    if (base.isEmpty) throw BackendError(BackendErrorKind.notConfigured);
    final uri = Uri.tryParse('$base$path');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw BackendError(BackendErrorKind.notConfigured, detail: 'adresse invalide');
    }
    return uri;
  }

  Future<dynamic> get(String path, {Duration timeout = readTimeout}) =>
      _send(() => http.get(_uri(path), headers: _config.headers), timeout);

  Future<dynamic> post(String path, {Object? body, Duration timeout = readTimeout}) => _send(
        () => http.post(_uri(path), headers: _config.headers, body: body == null ? null : jsonEncode(body)),
        timeout,
      );

  Future<dynamic> delete(String path, {Duration timeout = readTimeout}) =>
      _send(() => http.delete(_uri(path), headers: _config.headers), timeout);

  /// Decoded JSON body, or null for an empty/204 answer.
  Future<dynamic> _send(Future<http.Response> Function() call, Duration timeout) async {
    final http.Response resp;
    try {
      resp = await call().timeout(timeout);
    } on BackendError {
      rethrow;
    } on TimeoutException {
      throw BackendError(BackendErrorKind.timeout);
    } on SocketException catch (e) {
      throw BackendError(BackendErrorKind.unreachable, detail: e.osError?.message ?? e.message);
    } on HandshakeException {
      throw BackendError(BackendErrorKind.unreachable, detail: 'échec TLS');
    } on http.ClientException catch (e) {
      throw BackendError(BackendErrorKind.unreachable, detail: e.message);
    }

    final status = resp.statusCode;
    if (status == 401 || status == 403) {
      throw BackendError(BackendErrorKind.unauthorized, statusCode: status);
    }
    if (status >= 500) {
      throw BackendError(BackendErrorKind.server, statusCode: status, detail: BackendError.serverDetail(resp.body));
    }
    if (status >= 400) {
      throw BackendError(BackendErrorKind.rejected, statusCode: status, detail: BackendError.serverDetail(resp.body));
    }
    if (status == 204 || resp.body.trim().isEmpty) return null;
    try {
      return jsonDecode(resp.body);
    } on FormatException {
      throw BackendError(BackendErrorKind.badResponse, statusCode: status);
    }
  }
}

/// The JSON object of an answer, or a [BackendError] when the server sent anything else.
Map<String, dynamic> asObject(dynamic body) {
  if (body is Map<String, dynamic>) return body;
  throw BackendError(BackendErrorKind.badResponse);
}
