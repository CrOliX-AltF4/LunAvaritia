import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/models/assistant_identity.dart';
import 'package:lunavaritia/services/identity_store.dart';

void main() {
  group('AssistantIdentity', () {
    test('LunAcedia answers: its own name, no companion', () {
      final id = AssistantIdentity.fromJson({'name': 'Iris', 'kind': 'lunacedia'});
      expect(id.name, 'Iris');
      expect(id.isCompanion, isFalse);
    });

    test('the hub answers: its character is a companion', () {
      final id = AssistantIdentity.fromJson({'name': 'Hoshi', 'kind': 'natsume'});
      expect(id.name, 'Hoshi');
      expect(id.isCompanion, isTrue);
    });

    test('a missing or blank name falls back to the neutral one, never to a name written in the app', () {
      expect(AssistantIdentity.fromJson({}).name, 'Assistant');
      expect(AssistantIdentity.fromJson({'name': '  '}).name, 'Assistant');
      expect(AssistantIdentity.fromJson({'name': 42}).name, 'Assistant');
    });

    test('toJson round-trips', () {
      const id = AssistantIdentity(name: 'Hoshi', isCompanion: true);
      final back = AssistantIdentity.fromJson(id.toJson());
      expect(back.name, id.name);
      expect(back.isCompanion, id.isCompanion);
    });
  });

  group('IdentityStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('nothing cached on a fresh install', () async {
      expect(await const IdentityStore().load(), isNull);
    });

    test('keeps the last identity the server gave', () async {
      const store = IdentityStore();
      await store.save(const AssistantIdentity(name: 'Iris', isCompanion: false));
      final back = await store.load();
      expect(back!.name, 'Iris');
      expect(back.isCompanion, isFalse);
    });

    test('a corrupt cache is ignored, not a crash', () async {
      SharedPreferences.setMockInitialValues({'assistant_identity': '{not json'});
      expect(await const IdentityStore().load(), isNull);
    });
  });
}
