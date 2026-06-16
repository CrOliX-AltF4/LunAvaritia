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
}
