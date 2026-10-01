import 'package:flutter_test/flutter_test.dart';

import 'package:lunavaritia/widgets/app_drawer.dart';

import '../support/fakes.dart';

void main() {
  test('groups topics by last activity: today, the last 7 days, older — in the order given', () {
    final now = DateTime(2026, 10, 1, 15);
    final groups = groupTopicsByDay([
      topic('a', 'Ce matin', updatedAt: DateTime(2026, 10, 1, 8)),
      topic('b', 'Minuit pile', updatedAt: DateTime(2026, 10, 1)),
      topic('c', 'Hier', updatedAt: DateTime(2026, 9, 30, 23)),
      topic('d', 'Il y a 7 jours', updatedAt: DateTime(2026, 9, 24)),
      topic('e', 'Vieux', updatedAt: DateTime(2026, 9, 23, 23)),
    ], now);

    expect(groups.map((g) => g.label), ['Aujourd’hui', '7 derniers jours', 'Plus ancien']);
    expect(groups[0].topics.map((t) => t.id), ['a', 'b']);
    expect(groups[1].topics.map((t) => t.id), ['c', 'd']);
    expect(groups[2].topics.map((t) => t.id), ['e']);
  });

  test('leaves out an empty group', () {
    final groups = groupTopicsByDay([topic('a', 'x', updatedAt: DateTime(2026, 10, 1, 9))], DateTime(2026, 10, 1, 10));
    expect(groups.map((g) => g.label), ['Aujourd’hui']);
  });
}
