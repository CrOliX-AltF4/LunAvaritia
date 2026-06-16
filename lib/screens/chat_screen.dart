import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input      = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().refreshStatus();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    context.read<ChatProvider>().send(text).then((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat   = context.watch<ChatProvider>();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('Natsume', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: chat.loadingStatus ? null : () => chat.refreshStatus(),
            tooltip: 'Rafraîchir le statut',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _StatusBar(chat: chat),
        ),
      ),
      body: Column(
        children: [
          if (chat.error != null)
            MaterialBanner(
              content: Text(chat.error!, style: const TextStyle(fontSize: 13)),
              actions: [
                TextButton(
                  onPressed: chat.clearError,
                  child: const Text('OK'),
                ),
              ],
              backgroundColor: colors.errorContainer,
            ),
          Expanded(
            child: chat.messages.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: chat.messages.length + (chat.sending ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == chat.messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: _TypingIndicator(),
                          ),
                        );
                      }
                      return ChatBubble(message: chat.messages[i]);
                    },
                  ),
          ),
          _InputBar(controller: _input, focusNode: _focusNode, onSend: _send, sending: chat.sending),
        ],
      ),
    );
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.chat});
  final ChatProvider chat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = chat.status;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: colors.surfaceContainerHigh,
      child: Row(
        children: [
          _MoodChip(mood: status.mood),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Énergie', style: TextStyle(fontSize: 10, color: colors.outline)),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: status.energy.clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            status.affinityTier,
            style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.mood});
  final String mood;

  static const _moodEmoji = {
    'happy':    '😊',
    'playful':  '😄',
    'neutral':  '😐',
    'tired':    '😴',
    'focused':  '🎯',
    'annoyed':  '😤',
  };

  @override
  Widget build(BuildContext context) {
    final emoji = _moodEmoji[mood.toLowerCase()] ?? '😐';
    return Chip(
      label: Text('$emoji $mood', style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.sending,
  });

  final TextEditingController controller;
  final FocusNode             focusNode;
  final VoidCallback          onSend;
  final bool                  sending;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message à Natsume…',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: sending
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 40, height: 40,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton.filled(
                      key: const ValueKey('send'),
                      onPressed: onSend,
                      icon: const Icon(Icons.send_rounded),
                      tooltip: 'Envoyer',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: colors.primaryContainer,
            child: Text('N', style: TextStyle(fontSize: 32, color: colors.onPrimaryContainer)),
          ),
          const SizedBox(height: 16),
          Text(
            'Parle à Natsume',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Pose une question ou donne-lui une tâche.',
            style: TextStyle(color: colors.outline, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim  = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _anim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
            child: CircleAvatar(radius: 3, backgroundColor: colors.outline),
          )),
        ),
      ),
    );
  }
}
