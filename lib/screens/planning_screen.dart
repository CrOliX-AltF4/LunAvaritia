import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planning.dart';
import '../providers/planning_controller.dart';
import '../providers/shell_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/shell_widgets.dart';

/// The planning (maquette du 2026-10-17): Aujourd'hui, Semaine, Tâches, En retard. « Fait » completes a task at
/// Google Tasks; a conflict opens its box item, where its ways out are chosen. Nothing else is written from here.
class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

const _weekdays = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre',
  'décembre',
];

String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
String _dayTitle(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
String _dayShort(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day}';

class _PlanningScreenState extends State<PlanningScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<PlanningController>().load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final planning = context.watch<PlanningController>();
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), titleSpacing: 0, title: const Text('Planning')),
      body: Column(
        children: [
          _Views(current: planning.view, late: planning.lateCount, onSelected: planning.show),
          Expanded(child: _body(planning)),
        ],
      ),
    );
  }

  Widget _body(PlanningController planning) {
    final snap = planning.snapshot;
    if (snap == null && planning.loading) return const Center(child: CircularProgressIndicator());
    if (snap == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(planning.error ?? "Le planning n'a pas pu être lu.",
                  textAlign: TextAlign.center, style: da(color: Palette.lune)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: planning.load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    final children = switch (planning.view) {
      PlanningView.today => _today(planning, snap),
      PlanningView.week => _week(planning, snap),
      PlanningView.tasks => _tasks(planning, snap),
      PlanningView.late => _late(planning, snap),
    };
    return RefreshIndicator(
      onRefresh: planning.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (!snap.complete)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text("Le planning n'a pas encore été lu en entier : il peut manquer des éléments.",
                  style: da(size: 12.5, color: Palette.brume)),
            ),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _today(PlanningController planning, PlanningSnapshot snap) {
    final day = planning.day;
    final isToday = day == planning.today;
    final events = snap.eventsOn(day);
    final tasks = [
      ...snap.tasksOn(day),
      // Today also carries what is late — never another day.
      if (isToday) ...snap.late(planning.today),
    ];
    return [
      Text(_dayTitle(day), style: da(size: 13, color: Palette.lune)),
      const SizedBox(height: 12),
      for (final c in snap.conflictsOn(day)) _ConflictBanner(conflict: c, snap: snap),
      _section('Rendez-vous'),
      if (events.isEmpty) _quiet('Rien de prévu.'),
      for (final e in events) _EventRow(event: e, overlaps: _overlapping(snap, e)),
      _section(isToday ? "À faire aujourd'hui" : 'À faire ce jour-là'),
      if (tasks.isEmpty) _quiet('Aucune tâche.'),
      for (final t in tasks) _TaskRow(key: ValueKey(t.id), task: t, today: planning.today),
    ];
  }

  /// « chevauche Dentiste »: the earlier event a conflict says this one overlaps.
  String? _overlapping(PlanningSnapshot snap, PlanningEvent e) {
    for (final c in snap.conflicts) {
      if (!c.eventIds.contains(e.id)) continue;
      final other = snap.event(c.eventIds.firstWhere((id) => id != e.id, orElse: () => ''));
      if (other != null && other.start.isBefore(e.start)) return other.title;
    }
    return null;
  }

  List<Widget> _week(PlanningController planning, PlanningSnapshot snap) => [
        for (final d in planning.week) _DayRow(day: d, snap: snap, onTap: () => planning.openDay(d)),
        const SizedBox(height: 12),
        Text("Toucher un jour ouvre sa vue « Aujourd'hui ».", style: da(size: 12, color: Palette.brume)),
      ];

  List<Widget> _tasks(PlanningController planning, PlanningSnapshot snap) {
    final lists = <String, List<PlanningTask>>{};
    for (final t in snap.tasks.where((t) => t.open)) {
      lists.putIfAbsent(t.listTitle, () => []).add(t);
    }
    if (lists.isEmpty) return [_quiet('Aucune tâche ouverte.')];
    return [
      for (final e in lists.entries) ...[
        _section(e.key),
        for (final t in e.value) _TaskRow(key: ValueKey(t.id), task: t, today: planning.today, showList: false),
      ],
    ];
  }

  List<Widget> _late(PlanningController planning, PlanningSnapshot snap) {
    final late = snap.late(planning.today);
    if (late.isEmpty) return [_quiet('Rien en retard.')];
    return [for (final t in late) _TaskRow(key: ValueKey(t.id), task: t, today: planning.today)];
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(text, style: da(size: 12, color: Palette.lune, letterSpacing: 0.7)),
      );

  Widget _quiet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: da(size: 13, color: Palette.brume)),
      );
}

class _Views extends StatelessWidget {
  const _Views({required this.current, required this.late, required this.onSelected});

  final PlanningView current;
  final int late;
  final ValueChanged<PlanningView> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = {
      PlanningView.today: "Aujourd'hui",
      PlanningView.week: 'Semaine',
      PlanningView.tasks: 'Tâches',
      PlanningView.late: late > 0 ? 'En retard · $late' : 'En retard',
    };
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          for (final e in labels.entries)
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
}

/// A conflict of the day: its ways out are chosen on its box item.
class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.conflict, required this.snap});

  final PlanningConflict conflict;
  final PlanningSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final names = conflict.eventIds.map((id) => snap.event(id)?.title ?? '?').join(' et ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Palette.encre3,
        shape: const RoundedRectangleBorder(side: BorderSide(color: Palette.filetFort)),
        child: InkWell(
          onTap: () => context
              .read<ShellController>()
              .go(BoxItemDestination(conflict.id, back: const PlanningDestination())),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_outlined, size: 18, color: Palette.ivoire),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Conflit à ${_clock(conflict.from)} — $names', style: da(size: 14, weight: 500)),
                      const SizedBox(height: 2),
                      Text('Créneaux libres proposés · Choisir →', style: da(size: 12.5, color: Palette.lune)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, this.overlaps});

  final PlanningEvent event;
  final String? overlaps;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (overlaps != null) 'chevauche $overlaps' else if (!event.allDay) "jusqu'à ${_clock(event.end)}",
      if (event.location != null && event.location!.isNotEmpty) event.location!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.filet))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(event.allDay ? 'Journée' : _clock(event.start), style: da(size: 13, color: Palette.lune)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: da(size: 14.5)),
                if (details.isNotEmpty) Text(details, style: da(size: 12.5, color: Palette.brume)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatefulWidget {
  const _TaskRow({super.key, required this.task, required this.today, this.showList = true});

  final PlanningTask task;
  final DateTime today;
  final bool showList;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _busy = false;

  Future<void> _done() async {
    setState(() => _busy = true);
    final why = await context.read<PlanningController>().done(widget.task);
    if (!mounted) return;
    setState(() => _busy = false);
    if (why != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pas fait : $why')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final late = t.daysLate(widget.today);
    final details = [
      if (late > 0) 'En retard de $late j',
      if (widget.showList && t.listTitle.isNotEmpty) t.listTitle,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.filet))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: da(size: 14.5)),
                if (details.isNotEmpty) Text(details, style: da(size: 12.5, color: Palette.brume)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _busy ? null : _done, child: const Text('Fait')),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.snap, required this.onTap});

  final DateTime day;
  final PlanningSnapshot snap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final events = snap.eventsOn(day);
    final tasks = snap.tasksOn(day);
    final conflicts = snap.conflictsOn(day).length;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.filet))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: _dayShort(day), style: da(family: serif, size: 18, weight: 600)),
              if (conflicts > 0)
                TextSpan(
                  text: ' · $conflicts conflit${conflicts > 1 ? 's' : ''}',
                  style: da(size: 12.5, color: Palette.lune),
                ),
            ])),
            const SizedBox(height: 4),
            Text(
              events.isEmpty
                  ? 'Rien de prévu'
                  : events
                      .map((e) => e.allDay ? 'Journée entière · ${e.title}' : '${_clock(e.start)} ${e.title}')
                      .join(' · '),
              style: da(size: 13, color: events.isEmpty ? Palette.brume : Palette.lune),
            ),
            if (tasks.isNotEmpty)
              Text(
                tasks.length == 1 ? '1 tâche · ${tasks.first.title}' : '${tasks.length} tâches',
                style: da(size: 12.5, color: Palette.brume),
              ),
          ],
        ),
      ),
    );
  }
}
