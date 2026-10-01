import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lunavaritia/models/alert.dart';
import 'package:lunavaritia/providers/alert_provider.dart';
import 'package:lunavaritia/providers/shell_controller.dart';
import 'package:lunavaritia/screens/alert_feed_screen.dart';

import '../support/fakes.dart';

Alert _alert({String id = 'test-1', String title = 'PR merged', String? key}) => Alert(
      id: id,
      type: 'github',
      source: AlertSource.github,
      title: title,
      priority: AlertPriority.normal,
      ts: DateTime(2026, 6, 22),
      read: false,
      key: key,
    );

Widget _buildScreen(ShellController shell, {List<Alert>? alerts}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: shell),
      ChangeNotifierProvider<AlertProvider>(create: (_) => AlertProvider(FakeBackend(alerts: alerts, digest: 'digest'))),
    ],
    child: const MaterialApp(home: AlertFeedScreen()),
  );
}

void main() {
  group('AlertFeedScreen (the box until M4)', () {
    testWidgets('is titled Boîte', (tester) async {
      await tester.pumpWidget(_buildScreen(ShellController()));
      await tester.pumpAndSettle();

      expect(find.text('Boîte'), findsOneWidget);
    });

    testWidgets('shows empty state when no alerts', (tester) async {
      await tester.pumpWidget(_buildScreen(ShellController()));
      await tester.pumpAndSettle();

      expect(find.text('Aucune alerte'), findsOneWidget);
    });

    testWidgets('shows alert title when alerts are present', (tester) async {
      await tester.pumpWidget(_buildScreen(ShellController(), alerts: [_alert()]));
      await tester.pumpAndSettle();

      expect(find.text('PR merged'), findsOneWidget);
    });

    testWidgets('tapping the digest button shows the digest sheet', (tester) async {
      await tester.pumpWidget(_buildScreen(ShellController()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
      await tester.pumpAndSettle();

      expect(find.text('digest'), findsOneWidget);
    });

    testWidgets('"Traiter" opens a new topic about the element — only for an element of the box', (tester) async {
      final shell = ShellController(initial: const BoxDestination());
      await tester.pumpWidget(_buildScreen(shell, alerts: [
        _alert(id: 'a1', title: 'Facture', key: 'email-42'),
        _alert(id: 'a2', title: 'Système'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Traiter'), findsOneWidget);
      await tester.tap(find.text('Traiter'));
      await tester.pump();

      final destination = shell.current;
      expect(destination, isA<HomeDestination>());
      expect((destination as HomeDestination).aboutKey, 'email-42');
      expect(destination.aboutTitle, 'Facture');
    });
  });
}
