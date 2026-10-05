import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../models/topic.dart';
import '../providers/box_controller.dart';
import '../providers/identity_provider.dart';
import '../providers/shell_controller.dart';
import '../providers/topics_provider.dart';
import '../screens/home_screen.dart' show UrgentBadge;
import '../theme/app_theme.dart';
import 'shell_widgets.dart';

/// The drawer (DA1 « Tiroir »): new topic, the box, the topics by date, the archive, the settings.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.wired, required this.paired, this.now = DateTime.now});

  /// Wired to the hub (else LunAcedia on its own).
  final bool wired;
  final bool paired;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final identity = context.watch<IdentityProvider>().identity;
    final box = context.watch<BoxController>();
    final topicsProvider = context.watch<TopicsProvider>();
    final urgent = box.urgentUnreadCount;
    final groups = groupTopicsByDay(topicsProvider.topics, now());
    final currentId = switch (shell.current) {
      TopicDestination(:final id) => id,
      _ => null,
    };

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(identity.name, style: da(family: serif, size: 26, weight: 500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(paired ? Icons.link : Icons.link_off, size: 14, color: Palette.lune),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${wired ? 'Câblé au hub' : 'LunAcedia'} · ${paired ? 'appareil appairé' : 'non appairé'}',
                          style: da(size: 12, color: Palette.lune),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OutlinedButton.icon(
                onPressed: () => shell.go(const HomeDestination()),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau sujet'),
              ),
            ),
            const Divider(),
            _NavRow(
              icon: Icons.inbox_outlined,
              label: 'Boîte',
              selected: shell.current is BoxDestination ||
                  shell.current is BoxItemDestination ||
                  shell.current is TrashDestination,
              trailing: [
                if (urgent > 0) UrgentBadge(label: '$urgent'),
                const SizedBox(width: 10),
                Text('${box.unreadCount}', style: da(size: 13, color: Palette.lune)),
              ],
              onTap: () => shell.go(const BoxDestination()),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  if (topicsProvider.topics.isEmpty && !topicsProvider.loading)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Text(
                        topicsProvider.error ?? 'Aucun sujet pour l’instant.',
                        style: da(size: 13, color: Palette.lune),
                      ),
                    ),
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                      child: Text(group.label.toUpperCase(), style: da(size: 12, color: Palette.lune, letterSpacing: 0.7)),
                    ),
                    for (final topic in group.topics)
                      _TopicRow(
                        topic: topic,
                        selected: topic.id == currentId,
                        onTap: () => shell.go(TopicDestination(topic.id)),
                        onLongPress: () => showTopicActions(context, topic),
                      ),
                  ],
                  _NavRow(
                    label: 'Sujets archivés',
                    color: Palette.lavis,
                    selected: shell.current is ArchivedDestination,
                    onTap: () => shell.go(const ArchivedDestination()),
                  ),
                ],
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _NavRow(
                    icon: Icons.tune,
                    label: 'Réglages',
                    selected: shell.current is SettingsDestination,
                    onTap: () => shell.go(const SettingsDestination()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (_, snap) => Text(snap.data?.version ?? '', style: da(size: 12, color: Palette.lune)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.trailing = const [],
    this.color = Palette.ivoire,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool selected;
  final List<Widget> trailing;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          color: selected ? const Color(0x0FF0EBE1) : null,
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 14)],
              Expanded(child: Text(label, style: da(color: color))),
              ...trailing,
            ],
          ),
        ),
      );
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.selected, required this.onTap, required this.onLongPress});

  final Topic topic;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          color: selected ? const Color(0x0FF0EBE1) : null,
          child: Text(topic.title, style: da(), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}

class TopicGroup {
  const TopicGroup(this.label, this.topics);
  final String label;
  final List<Topic> topics;
}

/// Today, the last 7 days, older — by last activity, most recent first (the order the server gives).
List<TopicGroup> groupTopicsByDay(List<Topic> topics, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final weekAgo = today.subtract(const Duration(days: 7));
  final buckets = <String, List<Topic>>{'Aujourd’hui': [], '7 derniers jours': [], 'Plus ancien': []};
  for (final t in topics) {
    final key = !t.updatedAt.isBefore(today)
        ? 'Aujourd’hui'
        : !t.updatedAt.isBefore(weekAgo)
            ? '7 derniers jours'
            : 'Plus ancien';
    buckets[key]!.add(t);
  }
  return [
    for (final e in buckets.entries)
      if (e.value.isNotEmpty) TopicGroup(e.key, e.value),
  ];
}
