// Topics (ADR-020 amendment 1): one conversation = one topic to deal with, stored by the server. The same shapes
// come from LunAcedia (`/api/conversations`) and from the hub (`/api/mobile/conversations`).

DateTime _date(Object? raw) => DateTime.tryParse(raw is String ? raw : '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);

String _str(Object? raw) => raw is String ? raw : '';

class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.archived,
    required this.messageCount,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  final int messageCount;

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: _str(json['id']),
        title: _str(json['title']).isEmpty ? 'Sans titre' : _str(json['title']),
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        archived: json['archived'] == true,
        messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
      );
}

enum TopicRole { user, assistant }

class TopicMessage {
  const TopicMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.external = false,
    this.about,
    this.agent,
  });

  final String id;
  final TopicRole role;
  final String text;
  final DateTime at;

  /// The answer read text written by a third party (a mail, an issue…) — said under it.
  final bool external;

  /// The box item a message is about (a notification's "Traiter").
  final String? about;
  final AgentOutcome? agent;

  factory TopicMessage.fromJson(Map<String, dynamic> json) {
    final agent = json['agent'];
    return TopicMessage(
      id: _str(json['id']),
      role: json['role'] == 'user' ? TopicRole.user : TopicRole.assistant,
      text: _str(json['text']),
      at: _date(json['at']),
      external: json['external'] == true,
      about: json['about'] is String ? json['about'] as String : null,
      agent: agent is Map<String, dynamic> ? AgentOutcome.fromJson(agent) : null,
    );
  }
}

/// What an agent run shows of itself (the structured answer, versioned in the contract): what it looked at, and
/// what it did or proposes to do.
class AgentOutcome {
  const AgentOutcome({required this.status, required this.items, required this.actions});

  /// done, limit_reached, unavailable, error.
  final String status;
  final List<CitedItem> items;
  final List<AgentAction> actions;

  factory AgentOutcome.fromJson(Map<String, dynamic> json) => AgentOutcome(
        status: _str(json['status']),
        items: [
          for (final i in (json['items'] as List<dynamic>? ?? const []))
            if (i is Map<String, dynamic>) CitedItem.fromJson(i),
        ],
        actions: [
          for (final a in (json['actions'] as List<dynamic>? ?? const []))
            if (a is Map<String, dynamic>) AgentAction.fromJson(a),
        ],
      );
}

/// An element of the box the answer cites — a mail, an event, an issue.
class CitedItem {
  const CitedItem({
    required this.key,
    required this.source,
    required this.title,
    this.from,
    this.snippet,
    this.priority,
    this.at,
  });

  final String key;
  final String source;
  final String title;
  final String? from;
  final String? snippet;
  final String? priority;
  final DateTime? at;

  factory CitedItem.fromJson(Map<String, dynamic> json) => CitedItem(
        key: _str(json['key']),
        source: _str(json['source']),
        title: _str(json['title']),
        from: json['from'] is String ? json['from'] as String : null,
        snippet: json['snippet'] is String ? json['snippet'] as String : null,
        priority: json['priority'] is String ? json['priority'] as String : null,
        at: json['at'] is String ? _date(json['at']) : null,
      );
}

/// An action the agent did or proposes: executed, pending (waits for the user), refused, invalid, error.
class AgentAction {
  const AgentAction({
    required this.kind,
    required this.status,
    this.id,
    this.connector,
    this.reason,
    this.fields = const {},
  });

  final String kind;
  final String status;
  final String? id;
  final String? connector;
  final String? reason;

  /// The action's own content (`action` in the contract): a reply's body, a task's title…
  final Map<String, dynamic> fields;

  bool get isMemoryProposal => kind == 'propose_memory' || connector == 'memory';

  /// Waits for the user, and the user can settle it from the phone (memory proposals are settled in the panel).
  bool get isDecidable => status == 'pending' && !isMemoryProposal && (id ?? '').isNotEmpty;

  factory AgentAction.fromJson(Map<String, dynamic> json) {
    final action = json['action'];
    return AgentAction(
      kind: _str(json['kind']),
      status: _str(json['status']),
      id: json['id'] is String ? json['id'] as String : null,
      connector: json['connector'] is String ? json['connector'] as String : null,
      reason: json['reason'] is String ? json['reason'] as String : null,
      fields: action is Map<String, dynamic> ? action : const {},
    );
  }

  /// What the action does, in a few words.
  String get label => _kindLabels[kind] ?? kind.replaceAll('_', ' ');

  /// The text the user must see before agreeing: what will be sent, created or written.
  String? get preview {
    String? pick(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final nested = fields['fields'];
    return pick(fields, const ['body', 'text', 'label']) ??
        (nested is Map<String, dynamic> ? pick(nested, const ['title', 'summary', 'body']) : null);
  }

  static const _kindLabels = {
    'reply': 'Répondre au mail',
    'archive_email': 'Archiver le mail',
    'delete_email': 'Supprimer le mail',
    'mark_email_read': 'Marquer le mail comme lu',
    'mark_email_unread': 'Marquer le mail comme non lu',
    'create_event': 'Créer un événement',
    'update_event': "Modifier l'événement",
    'delete_event': "Supprimer l'événement",
    'create_task': 'Créer une tâche',
    'complete_task': 'Terminer la tâche',
    'delete_task': 'Supprimer la tâche',
    'comment_issue': 'Commenter',
    'add_label': 'Ajouter une étiquette',
    'create_issue': 'Ouvrir un ticket',
    'close_issue': 'Fermer le ticket',
    'open_pr': 'Ouvrir une PR',
    'merge_pr': 'Fusionner la PR',
    'mark_notification_read': 'Marquer la notification comme lue',
    'propose_memory': 'Retenir',
  };
}

/// One turn's answer: the topic as it is now, the user's message as stored, and the reply.
class TurnResult {
  const TurnResult({required this.topic, required this.userMessage, required this.message});

  final Topic topic;
  final TopicMessage userMessage;
  final TopicMessage message;

  factory TurnResult.fromJson(Map<String, dynamic> json) => TurnResult(
        topic: Topic.fromJson(json['conversation'] as Map<String, dynamic>? ?? const {}),
        userMessage: TopicMessage.fromJson(json['userMessage'] as Map<String, dynamic>? ?? const {}),
        message: TopicMessage.fromJson(json['message'] as Map<String, dynamic>? ?? const {}),
      );
}

/// A page of a topic's messages, oldest first.
class TopicPage {
  const TopicPage({required this.topic, required this.messages, required this.hasMore});

  final Topic topic;
  final List<TopicMessage> messages;

  /// Older messages exist before this page.
  final bool hasMore;

  factory TopicPage.fromJson(Map<String, dynamic> json) => TopicPage(
        topic: Topic.fromJson(json['conversation'] as Map<String, dynamic>? ?? const {}),
        messages: [
          for (final m in (json['messages'] as List<dynamic>? ?? const []))
            if (m is Map<String, dynamic>) TopicMessage.fromJson(m),
        ],
        hasMore: json['hasMore'] == true,
      );
}
