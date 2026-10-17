import '../models/mail_sort.dart';
import 'http_transport.dart';

/// The sorting of mail — LunAcedia's, the same paths and shapes standalone and through the hub (which relays it as is);
/// only the prefix changes.
class MailSortApi {
  MailSortApi(this._http, {required this.prefix});

  MailSortApi.lunacedia(HttpTransport http) : this(http, prefix: '/api');

  MailSortApi.hub(HttpTransport http) : this(http, prefix: '/api/mobile');

  final HttpTransport _http;
  final String prefix;

  Future<MailSortConfig> config() async =>
      MailSortConfig.fromJson(asObject(await _http.get('$prefix/config/mail-classes')));

  /// One switch of one class: `key` is visible, ai or rings.
  Future<MailSortConfig> setClass(MailClass c, String key, bool value) async => MailSortConfig.fromJson(asObject(
        await _http.patch('$prefix/config/mail-classes', body: {
          'classes': {
            c.name: {key: value},
          },
        }),
      ));

  Future<MailSortConfig> setPersonalSenders(List<String> senders) async => MailSortConfig.fromJson(
        asObject(await _http.patch('$prefix/config/mail-classes', body: {'personalSenders': senders})),
      );

  /// The rules that classify, and every rule's name (to say why a mail was kept out).
  Future<({List<SortRule> rules, Map<String, String> names})> rules() async {
    final data = asObject(await _http.get('$prefix/guard/rules'));
    final raw = (data['rules'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();
    return (
      rules: [for (final r in raw) if (SortRule.fromJson(r) case final s?) s],
      names: {for (final r in raw) '${r['id']}': '${r['name']}'},
    );
  }

  Future<void> setRule(String id, bool enabled) async {
    await _http.patch('$prefix/guard/rules/${Uri.encodeComponent(id)}', body: {'enabled': enabled});
  }

  Future<({List<KeptOut> items, int total})> keptOut(Map<String, String> ruleNames) async {
    final data = asObject(await _http.get('$prefix/guard/journal?limit=100'));
    return (
      items: [
        for (final e in (data['entries'] as List<dynamic>? ?? const []))
          if (e is Map<String, dynamic>) KeptOut.fromJson(e, ruleNames),
      ],
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// Back in the box.
  Future<void> restore(String key) async {
    await _http.post('$prefix/guard/journal/restore', body: {'dedupeKey': key});
  }
}
