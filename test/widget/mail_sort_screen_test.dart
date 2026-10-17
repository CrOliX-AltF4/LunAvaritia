import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lunavaritia/models/mail_sort.dart';
import 'package:lunavaritia/providers/box_controller.dart';
import 'package:lunavaritia/providers/shell_controller.dart';
import 'package:lunavaritia/screens/mail_sort_screen.dart';
import 'package:lunavaritia/services/backend_client.dart';
import 'package:lunavaritia/theme/app_theme.dart';

import '../support/fakes.dart';

// Sorting mail (maquette du 2026-10-17): every change saved at LunAcedia at once; what was kept out restorable.

late FakeBackend backend;
late ShellController shell;

Future<void> pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<BackendClient>.value(value: backend),
      ChangeNotifierProvider.value(value: shell),
      ChangeNotifierProvider(create: (_) => BoxController(backend)),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    backend = FakeBackend();
    shell = ShellController(initial: const MailSortDestination());
    backend.mailSort.rawRules = [
      {
        'id': 'r1',
        'name': 'ESPI',
        'enabled': true,
        'conditions': [
          {'field': 'from', 'op': 'domain', 'value': 'espi.fr'},
        ],
        'actions': [
          {'type': 'classify', 'mailClass': 'pro'},
        ],
      },
    ];
  });

  testWidgets('a class switch, a personal sender, a rule: each saved at once and shown as LunAcedia answered',
      (tester) async {
    await pump(tester, const MailSortScreen());
    expect(find.textContaining('hors IA'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('class-perso-ai')));
    await tester.pumpAndSettle();
    expect((backend.mailSort.classes['perso'] as Map)['ai'], isTrue);
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('class-perso-ai'))).value, isTrue);

    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    final senderField = find.widgetWithText(TextField, 'Nouvel expéditeur perso');
    await tester.scrollUntilVisible(senderField, 200, scrollable: list);
    await tester.enterText(senderField, 'maman@famille.fr');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Ajouter').first);
    await tester.pumpAndSettle();
    expect(backend.mailSort.senders, ['maman@famille.fr']);
    expect(find.widgetWithText(InputChip, 'maman@famille.fr'), findsOneWidget);

    // A forwarded box: added, then given a class by default.
    await tester.scrollUntilVisible(find.byKey(const ValueKey('mailbox-new')), 200, scrollable: list);
    await tester.enterText(find.byKey(const ValueKey('mailbox-new')), 'Pro@ESPI.fr');
    await tester.tap(find.byKey(const ValueKey('mailbox-add')));
    await tester.pumpAndSettle();
    expect(backend.mailSort.boxes.single.address, 'pro@espi.fr');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('mailbox-pro@espi.fr')), 200, scrollable: list);
    await tester.tap(find.text('Selon le mail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pro').last);
    await tester.pumpAndSettle();
    expect(backend.mailSort.boxes.single.mailClass, MailClass.pro);

    await tester.scrollUntilVisible(find.text('De « espi.fr » → Pro'), 200, scrollable: list);
    await tester.tap(find.byKey(const ValueKey('sort-rule-r1')));
    await tester.pumpAndSettle();
    expect(backend.mailSort.rawRules.single['enabled'], isFalse);
  });

  testWidgets('what was kept out says why, and comes back with « Restaurer »', (tester) async {
    backend.mailSort.journal = [
      {
        'ruleId': 'class:pub',
        'event': {'dedupeKey': 'email-1', 'title': 'Soldes', 'meta': {'from': 'Lumen'}},
      },
    ];
    await pump(tester, const KeptOutScreen());
    expect(find.text('Lumen · classe Pub (masquée)'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Restaurer'));
    await tester.pumpAndSettle();
    expect(backend.mailSort.restored, ['email-1']);
    expect(find.text("Rien n'est gardé hors de la boîte."), findsOneWidget);
  });
}
