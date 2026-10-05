import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lunavaritia/providers/shell_controller.dart';
import 'package:lunavaritia/providers/validation_controller.dart';
import 'package:lunavaritia/screens/validate_screen.dart';
import 'package:lunavaritia/services/backend_error.dart';
import 'package:lunavaritia/services/deep_link_router.dart';
import 'package:lunavaritia/services/validation_api.dart';
import 'package:lunavaritia/theme/app_theme.dart';

import '../support/fakes.dart';

// « À valider » — what waits for Master: memory proposals (wired) and pending writes.

PendingWrite write(String id, {String summary = 'Répondre à un mail — C’est noté.', bool untrusted = false}) =>
    PendingWrite(
      id: id,
      summary: summary,
      connector: 'Gmail',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 90)),
      untrusted: untrusted,
      byAgent: true,
    );

MemoryProposal proposal(String id, String text) =>
    MemoryProposal(id: id, text: text, editableText: text, origin: 'mobile', ts: DateTime.now());

late FakeBackend backend;
late ValidationController validation;

Future<void> pump(WidgetTester tester) async {
  validation = ValidationController(backend);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ShellController(initial: const ValidateDestination())),
      ChangeNotifierProvider.value(value: validation),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const ValidateScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => backend = FakeBackend());

  testWidgets('lists a pending write in words, when it expires, and that a third party’s text came first',
      (tester) async {
    backend.validation.writes = [write('a1', untrusted: true)];
    await pump(tester);
    expect(find.text('Répondre à un mail — C’est noté.'), findsOneWidget);
    expect(find.textContaining('expire dans 1 h'), findsOneWidget);
    expect(find.textContaining('texte d’un tiers'), findsOneWidget);
  });

  testWidgets('confirms a write and it leaves the list; a refusal keeps it and says why', (tester) async {
    backend.validation.writes = [write('a1'), write('a2', summary: 'Créer une tâche — Mutuelle')];
    backend.validation.decideError =
        BackendError(BackendErrorKind.server, detail: 'Action failed: mail no longer exists');
    await pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('mail no longer exists'), findsOneWidget);
    expect(find.text('Répondre à un mail — C’est noté.'), findsOneWidget);

    backend.validation.decideError = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Annuler').last);
    await tester.pumpAndSettle();
    expect(backend.validation.decisions.last, ('a2', false));
    expect(find.text('Créer une tâche — Mutuelle'), findsNothing);
  });

  testWidgets('wired: keeps, rewords or drops a memory proposal', (tester) async {
    backend.validation.proposalList = [proposal('p1', 'Le syndic prévient par mail.'), proposal('p2', 'Aime le thé.')];
    await pump(tester);
    expect(find.text('Pour la mémoire'), findsOneWidget);
    expect(find.text('« Le syndic prévient par mail. »'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Modifier').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Le syndic prévient toujours par mail.');
    await tester.tap(find.widgetWithText(FilledButton, 'Retenir ce texte'));
    await tester.pumpAndSettle();
    expect(backend.validation.approved, [('p1', 'Le syndic prévient toujours par mail.')]);

    await tester.tap(find.widgetWithText(TextButton, 'Écarter'));
    await tester.pumpAndSettle();
    expect(backend.validation.rejected, ['p2']);
    expect(find.text('Pour la mémoire'), findsNothing);
  });

  testWidgets('standalone: no memory section, and says when nothing waits', (tester) async {
    backend = FakeBackend();
    await pump(tester);
    expect(find.text('Pour la mémoire'), findsNothing);
    expect(find.textContaining('Rien en attente'), findsOneWidget);
  });

  test('a pending-write notification opens « À valider »', () {
    expect(resolveDeepLinkTarget({'type': 'system.action_pending', 'dedupeKey': 'action-1'}).validate, isTrue);
    expect(resolveDeepLinkTarget({'dedupeKey': 'email-1'}).validate, isFalse);
  });

  test('counts what waits — the drawer shows it', () async {
    backend.validation.writes = [write('a1')];
    backend.validation.proposalList = [proposal('p1', 'x')];
    final c = ValidationController(backend);
    await c.load();
    expect(c.count, 2);
  });
}
