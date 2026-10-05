import '../config/api_config.dart';
import 'backend_error.dart';
import 'http_transport.dart';

/// Pairing this phone: the server gives it its own token — limited to the mobile routes, revocable — in
/// exchange for a one-time code shown in LunAcedia's dashboard or the hub's panel. The phone never holds a master
/// secret any more.

/// Prefixes of a paired device's token — LunAcedia's and the hub's.
const lunacediaDeviceTokenPrefix = 'acd_dev_';
const hubDeviceTokenPrefix = 'nts_dev_';

bool isDeviceToken(String token) =>
    token.startsWith(lunacediaDeviceTokenPrefix) || token.startsWith(hubDeviceTokenPrefix);

enum PairingTarget { lunacedia, hub }

/// Where this server's pairing route is.
String pairingPath(PairingTarget target) =>
    target == PairingTarget.lunacedia ? '/api/devices/pair' : '/api/mobile/devices/pair';

/// Where a server stands with this phone: paired, still on an old shared secret, or nothing.
enum PairingState { paired, legacySecret, none }

PairingState pairingStateOf(String token) {
  if (token.trim().isEmpty) return PairingState.none;
  return isDeviceToken(token) ? PairingState.paired : PairingState.legacySecret;
}

/// Pairs with [url] using [code] and returns the device token. Throws a [BackendError]; see [pairingErrorMessage].
typedef PairDevice = Future<String> Function({
  required PairingTarget target,
  required String url,
  required String code,
  required String name,
});

Future<String> pairDevice({
  required PairingTarget target,
  required String url,
  required String code,
  required String name,
}) async {
  // No token: the code is the proof.
  final config = target == PairingTarget.lunacedia
      ? ApiConfig.fromForm(acediaUrl: url, acediaToken: '', hubUrl: '', hubToken: '')
      : ApiConfig.fromForm(acediaUrl: '', acediaToken: '', hubUrl: url, hubToken: '');
  final body = asObject(await HttpTransport(config).post(pairingPath(target), body: {'code': code, 'name': name}));
  final token = body['token'];
  if (token is! String || !isDeviceToken(token)) throw BackendError(BackendErrorKind.badResponse);
  return token;
}

/// What to tell the user when pairing failed — the transport's sentence, said in pairing terms where it differs.
String pairingErrorMessage(Object error) {
  if (error is BackendError) {
    if (error.kind == BackendErrorKind.unauthorized) return 'Code invalide ou expiré — demandez-en un nouveau.';
    if (error.statusCode == 429) return 'Trop d\'essais — attendez quelques minutes.';
    if (error.statusCode == 404) return 'Ce serveur ne sait pas encore appairer un appareil — mettez-le à jour.';
    return error.message;
  }
  return 'Erreur inattendue : $error';
}
