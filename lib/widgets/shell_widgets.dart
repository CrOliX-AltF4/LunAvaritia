import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/topic.dart';
import '../providers/shell_controller.dart';
import '../providers/topics_provider.dart';
import '../services/backend_error.dart';
import '../theme/app_theme.dart';

/// Opens the drawer — the leading button of every screen (DA1: no tabs, the drawer holds the rest).
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Ouvrir le tiroir',
        icon: const Icon(Icons.menu),
        onPressed: () => context.read<ShellController>().openDrawer(),
      );
}

/// The field at the bottom of a topic or of a new one.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.hint,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.filet))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                enabled: !sending,
                style: da(),
                decoration: InputDecoration(hintText: hint),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: sending
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton.filled(
                      tooltip: 'Envoyer',
                      style: IconButton.styleFrom(backgroundColor: Palette.ivoire, foregroundColor: Palette.encre),
                      onPressed: onSend,
                      icon: const Icon(Icons.arrow_upward),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rename, archive, delete — from a long press in the drawer or the topic's own menu (DA1).
Future<void> showTopicActions(BuildContext context, Topic topic) async {
  final topics = context.read<TopicsProvider>();
  final shell = context.read<ShellController>();
  final messenger = ScaffoldMessenger.of(context);

  Future<void> guarded(Future<void> Function() action) async {
    try {
      await action();
    } on BackendError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.title, style: Theme.of(sheet).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('${topic.messageCount} messages', style: Theme.of(sheet).textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Renommer'),
            onTap: () => Navigator.of(sheet).pop('rename'),
          ),
          ListTile(
            leading: Icon(topic.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
            title: Text(topic.archived ? 'Désarchiver' : 'Archiver'),
            onTap: () => Navigator.of(sheet).pop('archive'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Palette.rouge),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onPressed: () => Navigator.of(sheet).pop('delete'),
              icon: const Icon(Icons.delete_outline),
              label: Row(
                children: [
                  const Expanded(child: Text('Supprimer')),
                  Text('ce qui est entré en mémoire reste', style: da(size: 12, color: Palette.lune)),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case 'rename':
      final title = await _askTitle(context, topic.title);
      if (title != null && title.isNotEmpty) await guarded(() => topics.rename(topic.id, title));
    case 'archive':
      await guarded(() => topics.setArchived(topic.id, !topic.archived));
      if (shell.current case TopicDestination(:final id) when id == topic.id && !topic.archived) {
        shell.go(const HomeDestination());
      }
    case 'delete':
      await guarded(() async {
        await topics.delete(topic.id);
        if (shell.current case TopicDestination(:final id) when id == topic.id) shell.go(const HomeDestination());
      });
  }
}

Future<String?> _askTitle(BuildContext context, String current) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: Palette.encre2,
      title: const Text('Renommer le sujet'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Titre'),
        onSubmitted: (v) => Navigator.of(dialog).pop(v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.of(dialog).pop(controller.text.trim()), child: const Text('Renommer')),
      ],
    ),
  ).whenComplete(controller.dispose);
}
