import 'package:flutter_test/flutter_test.dart';

import 'package:lunavaritia/services/push_service.dart';

import '../support/fakes.dart';

// Lot S — a notification settled elsewhere is taken down, even on a closed phone: the servers send a silent message.

void main() {
  group('settled push', () {
    test('names the tags of a « settled » message only', () {
      expect(settledTagsOf({'type': 'settled', 'tags': 'email-1, action-a1,,alert-7'}),
          ['email-1', 'action-a1', 'alert-7']);
      expect(settledTagsOf({'type': 'system.action_pending', 'tags': 'x'}), isEmpty);
      expect(settledTagsOf({'type': 'settled'}), isEmpty);
    });

    test('takes each settled notification down', () async {
      final tray = FakeTray(['email-1', 'action-a1', 'email-2']);
      await dismissSettled(tray, ['email-1', 'action-a1', 'alert-9']);
      expect(tray.shown, ['email-2']);
    });
  });
}
