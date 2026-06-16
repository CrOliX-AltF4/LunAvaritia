enum AlertSource { email, calendar, tasks, github, discord, rss, ha, system }

enum AlertPriority { urgent, normal, info }

class Alert {
  Alert({
    required this.id,
    required this.type,
    required this.source,
    required this.title,
    required this.priority,
    required this.ts,
    required this.read,
    this.body,
    this.url,
  });

  final String id;
  final String type;
  final AlertSource source;
  final String title;
  final AlertPriority priority;
  final DateTime ts;
  final bool read;
  final String? body;
  final String? url;

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id:       json['id'] as String,
      type:     json['type'] as String? ?? '',
      source:   _parseSource(json['type'] as String? ?? ''),
      title:    json['title'] as String,
      priority: _parsePriority(json['priority'] as String? ?? 'normal'),
      ts:       DateTime.fromMillisecondsSinceEpoch(json['ts'] as int? ?? 0),
      read:     json['read'] as bool? ?? false,
      body:     json['body'] as String?,
      url:      json['url'] as String?,
    );
  }

  Alert copyWith({bool? read}) => Alert(
    id: id, type: type, source: source, title: title,
    priority: priority, ts: ts, read: read ?? this.read,
    body: body, url: url,
  );

  static AlertSource _parseSource(String type) {
    if (type.startsWith('email'))    return AlertSource.email;
    if (type.startsWith('calendar')) return AlertSource.calendar;
    if (type.startsWith('tasks'))    return AlertSource.tasks;
    if (type.startsWith('github'))   return AlertSource.github;
    if (type.startsWith('discord'))  return AlertSource.discord;
    if (type.startsWith('rss'))      return AlertSource.rss;
    if (type.startsWith('ha'))       return AlertSource.ha;
    return AlertSource.system;
  }

  static AlertPriority _parsePriority(String p) => switch (p) {
    'urgent' => AlertPriority.urgent,
    'info'   => AlertPriority.info,
    _        => AlertPriority.normal,
  };
}
