/// LunAcedia's sorting of mail: each mail gets a class at arrival, without any AI. A class says whether its mails show
/// in the box, may be read by a model, and ring.
enum MailClass { pro, perso, notification, pub, inconnu }

extension MailClassLabel on MailClass {
  String get label => switch (this) {
        MailClass.pro => 'Pro',
        MailClass.perso => 'Perso',
        MailClass.notification => 'Notifications',
        MailClass.pub => 'Pub',
        MailClass.inconnu => 'Non classé',
      };

  /// How LunAcedia recognises it.
  String get how => switch (this) {
        MailClass.pro => 'par tes règles',
        MailClass.perso => 'tes expéditeurs perso',
        MailClass.notification => 'Gmail : réseaux, mises à jour, forums, listes',
        MailClass.pub => 'Gmail : promotions',
        MailClass.inconnu => 'tout le reste',
      };
}

MailClass? mailClassOf(Object? name) => MailClass.values.where((c) => c.name == name).firstOrNull;

/// The three switches of a class.
class ClassSettings {
  const ClassSettings({required this.visible, required this.ai, required this.rings});

  final bool visible;
  final bool ai;
  final bool rings;

  factory ClassSettings.fromJson(Map<String, dynamic> json) => ClassSettings(
        visible: json['visible'] as bool? ?? true,
        ai: json['ai'] as bool? ?? true,
        rings: json['rings'] as bool? ?? true,
      );

  bool of(String key) => switch (key) { 'visible' => visible, 'ai' => ai, _ => rings };
}

class MailSortConfig {
  MailSortConfig({required this.classes, required this.personalSenders, required this.counts});

  final Map<MailClass, ClassSettings> classes;
  final List<String> personalSenders;

  /// Mails of the last 7 days, by class.
  final Map<MailClass, int> counts;

  factory MailSortConfig.fromJson(Map<String, dynamic> json) {
    final classes = json['classes'] is Map<String, dynamic> ? json['classes'] as Map<String, dynamic> : const {};
    final counts = json['counts'] is Map<String, dynamic> ? json['counts'] as Map<String, dynamic> : const {};
    return MailSortConfig(
      classes: {
        for (final c in MailClass.values)
          c: classes[c.name] is Map<String, dynamic>
              ? ClassSettings.fromJson(classes[c.name] as Map<String, dynamic>)
              : const ClassSettings(visible: true, ai: true, rings: true),
      },
      personalSenders: [for (final s in (json['personalSenders'] as List<dynamic>? ?? const [])) '$s'],
      counts: {for (final c in MailClass.values) c: (counts[c.name] as num?)?.toInt() ?? 0},
    );
  }
}

/// A rule of LunAcedia's that files mail in a class — the others (keep out, priority, gestures in Gmail) are not
/// shown here.
class SortRule {
  SortRule({required this.id, required this.when, required this.mailClass, required this.enabled});

  final String id;

  /// « De « espi.fr » », « Sujet « Votre commande » ».
  final String when;
  final MailClass mailClass;
  final bool enabled;

  /// Null when the rule does not classify.
  static SortRule? fromJson(Map<String, dynamic> json) {
    final actions = json['actions'] as List<dynamic>? ?? const [];
    final classify =
        actions.whereType<Map<String, dynamic>>().where((a) => a['type'] == 'classify').firstOrNull;
    final mailClass = mailClassOf(classify?['mailClass']);
    if (mailClass == null) return null;
    final conditions = (json['conditions'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();
    final c = conditions.firstOrNull ?? const <String, dynamic>{};
    final value = '${c['value'] ?? c['name'] ?? ''}';
    final when = switch (c['field']) {
      'from' => 'De « $value »',
      'subject' => 'Sujet « $value »',
      'snippet' => 'Texte « $value »',
      'label' => 'Libellé « $value »',
      _ => json['name'] as String? ?? '',
    };
    return SortRule(
      id: json['id'] as String? ?? '',
      when: when,
      mailClass: mailClass,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// A mail kept out of the box — by a rule, or by its class — restorable.
class KeptOut {
  KeptOut({required this.key, required this.title, required this.from, required this.why});

  final String key;
  final String title;
  final String from;

  /// « classe Pub (masquée) », « règle « AliExpress » », « règle supprimée ».
  final String why;

  factory KeptOut.fromJson(Map<String, dynamic> json, Map<String, String> ruleNames) {
    final event = json['event'] is Map<String, dynamic> ? json['event'] as Map<String, dynamic> : const {};
    final meta = event['meta'] is Map<String, dynamic> ? event['meta'] as Map<String, dynamic> : const {};
    final ruleId = json['ruleId'] as String? ?? '';
    final byClass = ruleId.startsWith('class:') ? mailClassOf(ruleId.substring('class:'.length)) : null;
    return KeptOut(
      key: event['dedupeKey'] as String? ?? '',
      title: event['title'] as String? ?? '',
      from: meta['from'] as String? ?? '',
      why: byClass != null
          ? 'classe ${byClass.label} (masquée)'
          : ruleNames[ruleId] != null
              ? 'règle « ${ruleNames[ruleId]} »'
              : 'règle supprimée',
    );
  }
}
