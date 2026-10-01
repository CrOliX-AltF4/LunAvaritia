import 'dart:convert';

/// Why a call to the server failed — distinct kinds so the app can say what actually happened
/// (live check 2026-09-28/29: every failure used to read "Connexion impossible", a slow Core and
/// a wrong token included).
enum BackendErrorKind {
  /// No server address saved yet.
  notConfigured,

  /// The address could not be reached at all (network down, wrong address, VPN off).
  unreachable,

  /// The server was reached but did not answer in time.
  timeout,

  /// 401/403 — the token is missing, wrong or revoked.
  unauthorized,

  /// Any other 4xx — the server understood and refused.
  rejected,

  /// 5xx — the server failed (503 is typically "not configured on the server side").
  server,

  /// A 2xx whose body is not the JSON the app expects.
  badResponse,
}

class BackendError implements Exception {
  BackendError(this.kind, {this.statusCode, this.detail});

  final BackendErrorKind kind;
  final int? statusCode;

  /// The server's own `{ error }` text when it sent one, else a technical hint — shown after the sentence.
  final String? detail;

  /// The sentence shown to the user, in French.
  String get message {
    final suffix = (detail != null && detail!.isNotEmpty) ? ' ($detail)' : '';
    return switch (kind) {
      BackendErrorKind.notConfigured =>
        "Aucun serveur configuré — renseigne l'adresse dans les paramètres.",
      BackendErrorKind.unreachable =>
        'Serveur injoignable — vérifie le réseau (ou le VPN) et l\'adresse.',
      BackendErrorKind.timeout => "Le serveur n'a pas répondu à temps.",
      BackendErrorKind.unauthorized => 'Jeton refusé par le serveur — vérifie-le dans les paramètres.',
      BackendErrorKind.rejected => 'Demande refusée par le serveur$suffix.',
      BackendErrorKind.server => statusCode == 503
          ? 'Service indisponible côté serveur$suffix.'
          : 'Erreur du serveur (${statusCode ?? '?'})$suffix.',
      BackendErrorKind.badResponse => 'Réponse illisible du serveur.',
    };
  }

  /// The `{ error }` field of a JSON error body, when there is one.
  static String? serverDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) return decoded['error'] as String;
    } on FormatException {
      // not JSON — no detail worth showing
    }
    return null;
  }

  @override
  String toString() => 'BackendError(${kind.name}${statusCode != null ? ', $statusCode' : ''}): ${detail ?? ''}';
}
