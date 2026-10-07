/// One item of the box as LunAcedia holds it — what is in the inbox at the source (Gmail, GitHub…).
enum BoxSource { email, calendar, tasks, github, rss, ha, system }

enum BoxPriority { urgent, normal, info }

/// Master's own gestures on an item, applied at the source — never the agent's writes. No "unread": opening is
/// reading (2026-10-07).
enum BoxGesture { open, read, archive, trash, spam, done }

/// What a gesture changed at the source: the item left the box, is now read, now unread — or nothing.
enum BoxChange { removed, read, unread }

class BoxItem {
  BoxItem({
    required this.key,
    required this.type,
    required this.source,
    required this.title,
    required this.priority,
    required this.ts,
    required this.read,
    this.body,
    this.url,
    this.from,
    this.priorityReason,
  });

  /// LunAcedia's key for the item (its dedupeKey) — what a gesture, a topic or a notification points at.
  final String key;
  final String type;
  final BoxSource source;
  final String title;
  final BoxPriority priority;
  final DateTime ts;
  final bool read;

  /// An excerpt; the full text comes with the "open" gesture.
  final String? body;
  final String? url;
  final String? from;

  /// Why it has its priority, in LunAcedia's words (« VIP », « Gmail : important ») — absent from an older server.
  final String? priorityReason;

  /// The gestures this source can do. LunAcedia refuses the others; the app does not offer them. A GitHub
  /// notification is marked read (it stays) or done (it leaves), as at GitHub.
  Set<BoxGesture> get gestures => switch (source) {
        BoxSource.email => {BoxGesture.read, BoxGesture.archive, BoxGesture.spam, BoxGesture.trash},
        BoxSource.github => {BoxGesture.read, BoxGesture.done},
        BoxSource.tasks => {BoxGesture.done},
        _ => <BoxGesture>{},
      };

  /// The swipe: archive a mail, mark a GitHub notification done. Never the trash, never a task's "Fait".
  BoxGesture? get swipe => switch (source) {
        BoxSource.email => BoxGesture.archive,
        BoxSource.github => BoxGesture.done,
        _ => null,
      };

  factory BoxItem.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map<String, dynamic> ? json['meta'] as Map<String, dynamic> : const <String, dynamic>{};
    return BoxItem(
      key: json['dedupeKey'] as String? ?? '',
      type: json['type'] as String? ?? '',
      source: BoxSource.values.firstWhere((s) => s.name == json['source'], orElse: () => BoxSource.system),
      title: json['title'] as String? ?? '',
      priority: BoxPriority.values.firstWhere((p) => p.name == json['priority'], orElse: () => BoxPriority.normal),
      ts: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int? ?? 0),
      read: json['read'] as bool? ?? false,
      body: json['body'] as String?,
      url: json['url'] as String?,
      from: meta['from'] as String?,
      priorityReason: json['priorityReason'] as String?,
    );
  }

  BoxItem copyWith({bool? read}) => BoxItem(
        key: key, type: type, source: source, title: title, priority: priority, ts: ts,
        read: read ?? this.read, body: body, url: url, from: from, priorityReason: priorityReason,
      );
}

class BoxPage {
  BoxPage({required this.items, required this.unread});

  /// Newest first.
  final List<BoxItem> items;
  final int unread;
}

class GestureResult {
  GestureResult({this.change, this.body});

  final BoxChange? change;

  /// The full text, for "open".
  final String? body;

  factory GestureResult.fromJson(Map<String, dynamic> json) => GestureResult(
        change: BoxChange.values.where((c) => c.name == json['change']).firstOrNull,
        body: json['body'] as String?,
      );
}

/// One page of Gmail's trash: [next] asks for the following one; [skipped] mails Gmail listed but could not give.
class TrashPage {
  TrashPage({required this.items, this.next, this.skipped = 0});

  final List<TrashItem> items;
  final String? next;
  final int skipped;

  factory TrashPage.fromJson(Map<String, dynamic> json) => TrashPage(
        items: [
          for (final t in (json['items'] as List<dynamic>? ?? const []))
            if (t is Map<String, dynamic>) TrashItem.fromJson(t),
        ],
        next: json['next'] as String?,
        skipped: json['skipped'] as int? ?? 0,
      );
}

/// A mail in Gmail's trash (kept 30 days by Gmail, nothing stored by LunAcedia).
class TrashItem {
  TrashItem({required this.id, required this.title, required this.from, required this.ts});

  final String id;
  final String title;
  final String from;
  final DateTime ts;

  factory TrashItem.fromJson(Map<String, dynamic> json) => TrashItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        from: json['from'] as String? ?? '',
        ts: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int? ?? 0),
      );
}
