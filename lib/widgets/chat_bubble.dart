import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!_isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: colors.primaryContainer,
              child: Text('N', style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isUser ? colors.primary : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(_isUser ? 18 : 4),
                      bottomRight: Radius.circular(_isUser ? 4 : 18),
                    ),
                  ),
                  child: SelectableText(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: _isUser ? colors.onPrimary : colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeago.format(message.ts, locale: 'fr'),
                  style: TextStyle(fontSize: 10, color: colors.outline),
                ),
              ],
            ),
          ),
          if (_isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
