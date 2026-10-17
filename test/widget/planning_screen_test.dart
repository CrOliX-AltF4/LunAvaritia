import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lunavaritia/models/planning.dart';
import 'package:lunavaritia/providers/planning_controller.dart';
import 'package:lunavaritia/providers/shell_controller.dart';
import 'package:lunavaritia/screens/planning_screen.dart';
import 'package:lunavaritia/services/backend_error.dart';
import 'package:lunavaritia/theme/app_theme.dart';

import '../support/fakes.dart';

// The planning (maquette du 2026-10-17): today with its conflict and what is late, the week, « Fait » at the source.

final monday = DateTime(2026, 10, 19, 8);
DateTime at(int day, int hour, [int minute = 0]) => DateTime(2026, 10, day, hour, minute);

PlanningEvent event(String id, String title, DateTime start, DateTime end) =>
    PlanningEvent(id: id, title: title, start: start, end: end, allDay: false);

PlanningTask task(String id, String title, DateTime due) =>
    PlanningTask(id: id, title: title, listTitle: 'Maison', open: true, due: due);

late FakeBackend backend;
late ShellController shell;
late PlanningController planning;

Future<void> pump(WidgetTester tester) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: shell),
      ChangeNotifierProvider.value(value: planning),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const PlanningScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    backend = FakeBackend();
    shell = ShellController(initial: const PlanningDestination());
    planning = PlanningController(backend, now: () => monday);
    backend.planning.snap = PlanningSnapshot(
      events: [
        event('p/a', 'Dentiste', at(19, 10), at(19, 11)),
        event('p/b', 'Appel Léa', at(19, 10, 30), at(19, 11, 30)),
        event('p/c', 'Cours', at(20, 9), at(20, 12)),
      ],
      tasks: [task('l/x', 'Renvoyer le dossier', DateTime(2026, 10, 19)), task('l/y', 'Payer la facture', DateTime(2026, 10, 17))],
      conflicts: [PlanningConflict(id: 'c1', eventIds: ['p/a', 'p/b'], from: at(19, 10, 30), to: at(19, 11))],
      complete: true,
    );
  });

  testWidgets('today: its conflict, its events, its tasks and what is late; the conflict opens its box item', (tester) async {
    await pump(tester);
    expect(find.text('Lundi 19 octobre'), findsOneWidget);
    expect(find.text('En retard · 1'), findsOneWidget);
    expect(find.text('Conflit à 10:30 — Dentiste et Appel Léa'), findsOneWidget);
    expect(find.text('chevauche Dentiste'), findsOneWidget);
    expect(find.text('Renvoyer le dossier'), findsOneWidget);
    expect(find.text('En retard de 2 j · Maison'), findsOneWidget);
    expect(find.text('Cours'), findsNothing);

    await tester.tap(find.textContaining('Conflit à 10:30'));
    await tester.pumpAndSettle();
    final to = shell.current as BoxItemDestination;
    expect(to.key, 'c1');
    expect(to.back, isA<PlanningDestination>());
  });

  testWidgets('« Fait » completes the task at the source; a refusal leaves it open and says why', (tester) async {
    await pump(tester);
    backend.planning.doneError = BackendError(BackendErrorKind.unreachable);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Fait').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Pas fait'), findsOneWidget);
    expect(find.text('Renvoyer le dossier'), findsOneWidget);

    backend.planning.doneError = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Fait').first);
    await tester.pumpAndSettle();
    expect(backend.planning.completed, ['l/x', 'l/x']);
    expect(find.text('Renvoyer le dossier'), findsNothing);
  });

  testWidgets('the week: seven days, a day touched opens its own « Aujourd\'hui »', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Semaine'));
    await tester.pumpAndSettle();
    expect(find.text('10:00 Dentiste · 10:30 Appel Léa'), findsOneWidget);
    expect(find.text('Rien de prévu'), findsNWidgets(5));

    await tester.tap(find.text('09:00 Cours'));
    await tester.pumpAndSettle();
    expect(find.text('Mardi 20 octobre'), findsOneWidget);
    expect(find.text('Cours'), findsOneWidget);
    // Late tasks belong to today only.
    expect(find.text('Payer la facture'), findsNothing);
  });

  testWidgets('says when the planning could not be read', (tester) async {
    backend.planning.snapshotError = BackendError(BackendErrorKind.unreachable);
    await pump(tester);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
