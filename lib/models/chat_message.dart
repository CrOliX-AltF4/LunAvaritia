enum MessageRole { user, natsume }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    required this.ts,
    this.id,
  });

  final String? id;
  final MessageRole role;
  final String text;
  final DateTime ts;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id:   json['id'] as String?,
      role: (json['role'] as String?) == 'user' ? MessageRole.user : MessageRole.natsume,
      text: json['text'] as String? ?? json['response'] as String? ?? '',
      ts:   DateTime.now(),
    );
  }

  /// Local persistence only (ChatHistoryStore) — distinct from fromJson's server-response
  /// shape (which never round-trips `ts`, always "now" on load from the server).
  Map<String, dynamic> toLocalJson() => {
    'id':   id,
    'role': role == MessageRole.user ? 'user' : 'natsume',
    'text': text,
    'ts':   ts.toIso8601String(),
  };

  factory ChatMessage.fromLocalJson(Map<String, dynamic> json) {
    return ChatMessage(
      id:   json['id'] as String?,
      role: (json['role'] as String?) == 'user' ? MessageRole.user : MessageRole.natsume,
      text: json['text'] as String? ?? '',
      ts:   DateTime.tryParse(json['ts'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
