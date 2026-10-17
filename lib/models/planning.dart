/// LunAcedia's planning: the calendar's events and the task lists' tasks, held as things to organise — not as
/// notifications. Facts as at the source; the conflicts' ways out live on their box item.
class PlanningEvent {
  PlanningEvent({required this.id, required this.title, required this.start, required this.end, required this.allDay, this.location});

  /// "calendarId/eventId".
  final String id;
  final String title;

  /// A timed event: local times. An all-day one: its first day, and the day after its last.
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? location;

  factory PlanningEvent.fromJson(Map<String, dynamic> json) {
    final allDay = json['allDay'] as bool? ?? false;
    DateTime at(String key) {
      final raw = json[key] as String? ?? '';
      // « 2026-10-20 » is a day, never a UTC midnight.
      return allDay ? _day(raw) : (DateTime.tryParse(raw)?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0));
    }

    return PlanningEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      start: at('start'),
      end: at('end'),
      allDay: allDay,
      location: json['location'] as String?,
    );
  }

  /// Whether it takes part of [day] (local midnight).
  bool on(DateTime day) {
    final next = DateTime(day.year, day.month, day.day + 1);
    return start.isBefore(next) && end.isAfter(day);
  }
}

class PlanningTask {
  PlanningTask({required this.id, required this.title, required this.listTitle, required this.open, this.due});

  /// "listId/taskId".
  final String id;
  final String title;
  final String listTitle;
  final bool open;

  /// A day — Google Tasks keeps no time of day.
  final DateTime? due;

  factory PlanningTask.fromJson(Map<String, dynamic> json) {
    final due = json['due'] as String?;
    return PlanningTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      listTitle: json['listTitle'] as String? ?? '',
      open: json['status'] != 'completed',
      due: due == null ? null : _day(due),
    );
  }

  PlanningTask completed() => PlanningTask(id: id, title: title, listTitle: listTitle, open: false, due: due);

  /// Days late on [today] (local midnight): 0 when not late, or without a day.
  int daysLate(DateTime today) => due == null || !due!.isBefore(today) ? 0 : today.difference(due!).inDays;
}

/// Two timed events that overlap. Its [id] is its box item's key: the ways out are chosen there.
class PlanningConflict {
  PlanningConflict({required this.id, required this.eventIds, required this.from, required this.to});

  final String id;
  final List<String> eventIds;
  final DateTime from;
  final DateTime to;

  factory PlanningConflict.fromJson(Map<String, dynamic> json) => PlanningConflict(
        id: json['id'] as String? ?? '',
        eventIds: [for (final e in (json['eventIds'] as List<dynamic>? ?? const [])) '$e'],
        from: DateTime.tryParse(json['from'] as String? ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
        to: DateTime.tryParse(json['to'] as String? ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class PlanningSnapshot {
  PlanningSnapshot({required this.events, required this.tasks, required this.conflicts, required this.complete});

  final List<PlanningEvent> events;
  final List<PlanningTask> tasks;
  final List<PlanningConflict> conflicts;

  /// Both sources read at least once — otherwise something may be missing, which the screen says.
  final bool complete;

  factory PlanningSnapshot.fromJson(Map<String, dynamic> json) => PlanningSnapshot(
        events: [
          for (final e in (json['events'] as List<dynamic>? ?? const []))
            if (e is Map<String, dynamic>) PlanningEvent.fromJson(e),
        ],
        tasks: [
          for (final t in (json['tasks'] as List<dynamic>? ?? const []))
            if (t is Map<String, dynamic>) PlanningTask.fromJson(t),
        ],
        conflicts: [
          for (final c in (json['conflicts'] as List<dynamic>? ?? const []))
            if (c is Map<String, dynamic>) PlanningConflict.fromJson(c),
        ],
        complete: json['complete'] as bool? ?? false,
      );

  PlanningEvent? event(String id) => events.where((e) => e.id == id).firstOrNull;

  /// [day]'s events, all-day ones first, then by start.
  List<PlanningEvent> eventsOn(DateTime day) => events.where((e) => e.on(day)).toList()
    ..sort((a, b) => a.allDay == b.allDay ? a.start.compareTo(b.start) : (a.allDay ? -1 : 1));

  /// The open tasks due on [day].
  List<PlanningTask> tasksOn(DateTime day) => tasks.where((t) => t.open && t.due != null && _sameDay(t.due!, day)).toList();

  /// The open tasks whose day is past, the latest first.
  List<PlanningTask> late(DateTime today) => tasks.where((t) => t.open && t.daysLate(today) > 0).toList()
    ..sort((a, b) => b.daysLate(today).compareTo(a.daysLate(today)));

  /// The conflicts that start on [day].
  List<PlanningConflict> conflictsOn(DateTime day) => conflicts.where((c) => _sameDay(c.from, day)).toList();

  PlanningSnapshot withTask(PlanningTask task) => PlanningSnapshot(
        events: events,
        tasks: [for (final t in tasks) t.id == task.id ? task : t],
        conflicts: conflicts,
        complete: complete,
      );
}

DateTime _day(String iso) {
  final p = iso.split('-').map(int.tryParse).toList();
  if (p.length < 3 || p.contains(null)) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime(p[0]!, p[1]!, p[2]!);
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
