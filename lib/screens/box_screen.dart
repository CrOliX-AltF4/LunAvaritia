import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/box_item.dart';
import '../providers/box_controller.dart';
import '../providers/shell_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/box_widgets.dart';
import '../widgets/shell_widgets.dart';

/// The box (DA1 « Boîte », DA-M4): LunAcedia's items, urgent first; a swipe archives a mail or
/// marks GitHub done, a long press offers the rest; the trash never on a swipe. Wired, the hub's own alerts sit apart.
class BoxScreen extends StatefulWidget {
  const BoxScreen({super.key});

  @override
  State<BoxScreen> createState() => _BoxScreenState();
}

class _BoxScreenState extends State<BoxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<BoxController>().load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final box = context.watch<BoxController>();
    final shell = context.read<ShellController>();

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        titleSpacing: 0,
        title: const Text('Boîte'),
        actions: [
          TextButton(onPressed: () => shell.go(const TrashDestination()), child: const Text('Corbeille')),
        ],
      ),
      body: Column(
        children: [
          _Chips(current: box.filter, onSelected: box.setFilter),
          Expanded(child: _body(context, box)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, BoxController box) {
    if (box.loading && !box.loaded) return const Center(child: CircularProgressIndicator());
    if (box.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(box.error!, textAlign: TextAlign.center, style: da(color: Palette.lune)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: box.load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    final urgent = box.urgent;
    final rest = box.rest;
    final hub = box.hubAlerts;
    return RefreshIndicator(
      onRefresh: box.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (urgent.isEmpty && rest.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('La boîte est vide.', style: da(color: Palette.lune))),
            ),
          if (urgent.isNotEmpty) ...[
            const BoxSectionTitle('Urgent'),
            for (final i in urgent) _BoxRow(item: i),
          ],
          if (rest.isNotEmpty) ...[
            const BoxSectionTitle('Le reste'),
            for (final i in rest) _BoxRow(item: i),
          ],
          if (hub.isNotEmpty) ...[
            const BoxSectionTitle('Du hub', trailing: 'seulement relié au hub'),
            for (final a in hub) _HubRow(alert: a),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.current, required this.onSelected});

  final BoxFilter current;
  final ValueChanged<BoxFilter> onSelected;

  static const _labels = {
    BoxFilter.all: 'Tout',
    BoxFilter.email: 'Mails',
    BoxFilter.calendar: 'Agenda',
    BoxFilter.github: 'GitHub',
    BoxFilter.tasks: 'Tâches',
  };

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            for (final e in _labels.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: current == e.key,
                  showCheckmark: false,
                  label: Text(e.value),
                  onSelected: (_) => onSelected(e.key),
                ),
              ),
          ],
        ),
      );
}

/// Runs a gesture and says why when the source refused it. True when done.
Future<bool> runBoxGesture(BuildContext context, BoxItem item, BoxGesture gesture) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await context.read<BoxController>().gesture(item, gesture);
  if (error != null) messenger.showSnackBar(SnackBar(content: Text('${gestureLabel(item, gesture)} : $error')));
  return error == null;
}

class _BoxRow extends StatelessWidget {
  const _BoxRow({required this.item});

  final BoxItem item;

  bool get _hasActions => item.priority == BoxPriority.urgent || item.source == BoxSource.tasks;

  @override
  Widget build(BuildContext context) {
    final shell = context.read<ShellController>();
    final done = item.gestures.contains(BoxGesture.done);
    final row = InkWell(
      onTap: () => shell.go(BoxItemDestination(item.key)),
      onLongPress: () => showBoxActions(context, item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Palette.encre,
          border: Border(top: BorderSide(color: Palette.filet)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: item.priority == BoxPriority.urgent ? Palette.rouge : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.read ? '${sourceLabel(item)} · lu' : sourceLabel(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: da(size: 13, color: item.read ? Palette.lavis : Palette.lune),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(boxTime(item.ts), style: da(size: 12, color: Palette.lune)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        da(size: 15, weight: item.read ? 300 : 400, color: item.read ? Palette.lune : Palette.ivoire),
                  ),
                  if (_hasActions)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => shell.go(HomeDestination(aboutKey: item.key, aboutTitle: item.title)),
                            child: const Text('Traiter'),
                          ),
                          if (done)
                            TextButton(
                              onPressed: () => runBoxGesture(context, item, BoxGesture.done),
                              child: Text(gestureLabel(item, BoxGesture.done)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final swipe = item.swipe;
    if (swipe == null) return row;
    return Dismissible(
      key: ValueKey('box-${item.key}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Palette.encre3,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Text(gestureLabel(item, swipe), style: da(size: 13)),
      ),
      // The item leaves only once the source said so; a refusal puts it back and says why.
      confirmDismiss: (_) => runBoxGesture(context, item, swipe),
      child: row,
    );
  }
}

/// The long press (DA-M4): read, deal with it, then the source's gestures — the trash apart, outlined in red.
Future<void> showBoxActions(BuildContext context, BoxItem item) {
  final shell = context.read<ShellController>();
  return showModalBottomSheet<void>(
    context: context,
    // Its own height, not a fixed share of the screen: on a small phone the trash must not fall off the bottom.
    isScrollControlled: true,
    backgroundColor: Palette.encre2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (sheet) {
      void close() => Navigator.of(sheet).pop();
      Future<void> gesture(BoxGesture g) async {
        close();
        await runBoxGesture(context, item, g);
      }

      final source = [
        if (item.gestures.contains(BoxGesture.read) && !item.read) BoxGesture.read,
        if (item.gestures.contains(BoxGesture.unread) && item.read) BoxGesture.unread,
        if (item.gestures.contains(BoxGesture.archive)) BoxGesture.archive,
        if (item.gestures.contains(BoxGesture.done)) BoxGesture.done,
      ];
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: da(family: serif, size: 22, weight: 500)),
                    const SizedBox(height: 4),
                    Text('${sourceLabel(item)} · ${boxTime(item.ts)}', style: da(size: 13, color: Palette.lune)),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Lire en entier'),
                onTap: () {
                  close();
                  shell.go(BoxItemDestination(item.key));
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Traiter'),
                onTap: () {
                  close();
                  shell.go(HomeDestination(aboutKey: item.key, aboutTitle: item.title));
                },
              ),
              for (final g in source)
                ListTile(
                  key: ValueKey('box-action-${g.name}'),
                  leading: Icon(switch (g) {
                    BoxGesture.archive => Icons.archive_outlined,
                    BoxGesture.done => Icons.check,
                    _ => Icons.circle_outlined,
                  }),
                  title: Text(gestureLabel(item, g)),
                  trailing:
                      g == item.swipe ? Text('aussi en balayant', style: da(size: 12, color: Palette.lune)) : null,
                  onTap: () => gesture(g),
                ),
              if (item.gestures.contains(BoxGesture.trash))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ListTile(
                    key: const ValueKey('box-action-trash'),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Palette.rouge),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Corbeille'),
                    trailing: Text('restaurable 30 jours', style: da(size: 12, color: Palette.lune)),
                    onTap: () => gesture(BoxGesture.trash),
                  ),
                )
              else
                const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
}

class _HubRow extends StatelessWidget {
  const _HubRow({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.filet))),
        child: Row(
          children: [
            Icon(alert.source == AlertSource.discord ? Icons.chat_bubble_outline : Icons.schedule,
                size: 18, color: Palette.lune),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${alert.source == AlertSource.discord ? 'Discord' : 'Système'} · ${boxTime(alert.ts)}',
                    style: da(size: 13, color: Palette.lune),
                  ),
                  const SizedBox(height: 4),
                  Text(alert.title, style: da(size: 15, color: alert.read ? Palette.lune : Palette.ivoire)),
                ],
              ),
            ),
            if (!alert.read)
              TextButton(
                onPressed: () => context.read<BoxController>().markHubAlertRead(alert.id),
                child: const Text('Lu'),
              ),
          ],
        ),
      );
}
