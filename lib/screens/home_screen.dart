import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/box_controller.dart';
import '../providers/identity_provider.dart';
import '../providers/shell_controller.dart';
import '../providers/topics_provider.dart';
import '../services/backend_error.dart';
import '../theme/app_theme.dart';
import '../widgets/shell_widgets.dart';

/// A new topic (DA1 « Accueil »): the field at the bottom, and a way back to what is waiting.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.aboutKey, this.aboutTitle, this.now = DateTime.now});

  /// The box item the new topic is about (a "Traiter").
  final String? aboutKey;
  final String? aboutTitle;
  final DateTime Function() now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// What « Traiter » asks when Master sends the field empty — a hint, never text he would have to delete.
const _aboutQuestion = "Qu'est-ce que je dois en faire ?";

class _HomeScreenState extends State<HomeScreen> {
  final _input = TextEditingController();
  bool _sending = false;
  String? _error;

  /// The message being sent, shown at once while the topic opens.
  String? _pending;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final typed = _input.text.trim();
    final text = typed.isEmpty && widget.aboutKey != null ? _aboutQuestion : typed;
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _pending = text;
      _input.clear();
    });
    final shell = context.read<ShellController>();
    try {
      final result = await context.read<TopicsProvider>().open(text, aboutKey: widget.aboutKey);
      shell.go(TopicDestination(result.topic.id));
    } on BackendError catch (e) {
      if (mounted) setState(() => _error = e.message);
      _restore(typed);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur inattendue : $e');
      _restore(typed);
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _pending = null;
        });
      }
    }
  }

  /// A failed opening gives the text back, unless Master already typed something else.
  void _restore(String typed) {
    if (mounted && _input.text.isEmpty) _input.text = typed;
  }

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<IdentityProvider>().identity;
    final box = context.watch<BoxController>();
    final topics = context.watch<TopicsProvider>().topics;
    final text = Theme.of(context).textTheme;
    final urgent = box.urgentUnreadCount;
    final greeting = widget.now().hour < 18 ? 'Bonjour.' : 'Bonsoir.';
    final shell = context.read<ShellController>();

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        titleSpacing: 0,
        title: Text(identity.name, style: text.titleLarge),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                if (_pending != null) ...[const ThinkingRow(), UserBubble(text: _pending!)],
                if (_pending == null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(greeting, style: text.displaySmall),
                      const SizedBox(height: 8),
                      Text(
                        "Un sujet par question. Ce qui mérite d'être retenu passe par la validation avant d'entrer "
                        'dans la mémoire.',
                        style: text.bodyLarge?.copyWith(color: Palette.lune),
                      ),
                      const SizedBox(height: 28),
                      const Divider(),
                      _Shortcut(
                        icon: Icons.inbox_outlined,
                        label: 'Boîte',
                        urgent: urgent,
                        count: box.unreadCount,
                        onTap: () => shell.go(const BoxDestination()),
                      ),
                      if (topics.isNotEmpty)
                        _Shortcut(
                          icon: Icons.history,
                          label: 'Reprendre « ${topics.first.title} »',
                          onTap: () => shell.go(TopicDestination(topics.first.id)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (widget.aboutKey != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right, size: 18, color: Palette.lune),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'À propos de : ${widget.aboutTitle ?? 'un élément de la boîte'}',
                      style: da(size: 13, color: Palette.lune),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ne plus lier à cet élément',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => shell.go(const HomeDestination()),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(_error!, style: da(size: 13, color: Palette.ivoire)),
            ),
          Composer(
              controller: _input,
              onSend: _open,
              sending: _sending,
              hint: widget.aboutKey != null ? _aboutQuestion : 'Nouveau sujet…'),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap, this.urgent = 0, this.count});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int urgent;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.filet))),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: da(), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (urgent > 0) UrgentBadge(label: urgent == 1 ? '1 urgent' : '$urgent urgents'),
            if (count != null) ...[
              const SizedBox(width: 10),
              Text('$count', style: da(size: 13, color: Palette.lune)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ivory on a red fill — red is never text on ink.
class UrgentBadge extends StatelessWidget {
  const UrgentBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Palette.rouge, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: da(size: 13)),
      );
}
