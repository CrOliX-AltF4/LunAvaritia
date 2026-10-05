import 'package:flutter_test/flutter_test.dart';

import 'package:lunavaritia/widgets/box_widgets.dart';

void main() {
  test('writes when an item came as DA1 does', () {
    final now = DateTime(2026, 10, 5, 15);
    expect(boxTime(DateTime(2026, 10, 5, 8, 42), now: now), '08:42');
    expect(boxTime(DateTime(2026, 10, 4, 23), now: now), 'hier');
    expect(boxTime(DateTime(2026, 9, 29, 9), now: now), 'mar.');
    expect(boxTime(DateTime(2026, 9, 28, 9), now: now), '28 sept.');
  });

  test("keeps the sender's name, the address stays in the reader", () {
    expect(senderName('Syndic <syndic@exemple.fr>'), 'Syndic');
    expect(senderName('"La Banque" <b@x.fr>'), 'La Banque');
    expect(senderName('<solo@x.fr>'), 'solo@x.fr');
  });
}
