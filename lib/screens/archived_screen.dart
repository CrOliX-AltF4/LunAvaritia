import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/shell_controller.dart';
import '../providers/topics_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shell_widgets.dart';

/// The archived topics — still readable, and can come back to the drawer.
class ArchivedScreen extends StatefulWidget {
  const ArchivedScreen({super.key});

  @override
  State<ArchivedScreen> createState() => _ArchivedScreenState();
}

class _ArchivedScreenState extends State<ArchivedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<TopicsProvider>().refreshArchived());
  }

  @override
  Widget build(BuildContext context) {
    final archived = context.watch<TopicsProvider>().archived;
    final shell = context.read<ShellController>();
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), titleSpacing: 0, title: const Text('Sujets archivés')),
      body: archived.isEmpty
          ? Center(child: Text('Aucun sujet archivé.', style: da(color: Palette.lune)))
          : ListView.separated(
              itemCount: archived.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final topic = archived[i];
                return ListTile(
                  title: Text(topic.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(timeago.format(topic.updatedAt, locale: 'fr')),
                  onTap: () => shell.go(TopicDestination(topic.id)),
                  onLongPress: () => showTopicActions(context, topic),
                );
              },
            ),
    );
  }
}
