import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/software_update/software_update_reminder_policy.dart';
import 'package:hazuki/services/software_update/software_update_reminder_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dismissal expires at local midnight, including the year boundary', () {
    var now = DateTime(2026, 12, 31, 23, 59);
    final policy = SoftwareUpdateReminderPolicy(now: () => now);
    final reminder = policy.remindLaterToday(
      currentVersion: '1',
      latestVersion: '2',
    );
    expect(reminder.date, '2026-12-31');
    expect(
      policy.shouldSkip(
        reminder: reminder,
        currentVersion: '1',
        latestVersion: '2',
      ),
      isTrue,
    );
    now = DateTime(2027, 1, 1);
    expect(
      policy.shouldSkip(
        reminder: reminder,
        currentVersion: '1',
        latestVersion: '2',
      ),
      isFalse,
    );
    expect(
      policy.remindLaterToday(currentVersion: '1', latestVersion: '2').date,
      '2027-01-01',
    );
  });

  test('only the exact version pair is skipped', () {
    final policy = SoftwareUpdateReminderPolicy(
      now: () => DateTime(2026, 9, 10),
    );
    final reminder = policy.remindLaterToday(
      currentVersion: '1.0',
      latestVersion: '2.0',
    );
    for (final versions in [('1.1', '2.0'), ('1.0', '2.1'), ('1.0', 'v2.0')]) {
      expect(
        policy.shouldSkip(
          reminder: reminder,
          currentVersion: versions.$1,
          latestVersion: versions.$2,
        ),
        isFalse,
      );
    }
    expect(
      policy.shouldSkip(
        reminder: null,
        currentVersion: '1.0',
        latestVersion: '2.0',
      ),
      isFalse,
    );
  });

  group('SharedPreferences reminder storage', () {
    const store = SharedPreferencesSoftwareUpdateReminderStore();
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'reads existing JSON and writes the same format under the supplied key',
      () async {
        final data = {
          'date': '2026-09-10',
          'currentVersion': '1.0',
          'latestVersion': '2.0',
        };
        SharedPreferences.setMockInitialValues({
          'startup': jsonEncode(data),
          'unrelated': 'keep',
        });
        final reminder = await store.read('startup');
        expect(reminder!.date, '2026-09-10');
        await store.write('manual', reminder);
        final prefs = await SharedPreferences.getInstance();
        expect(jsonDecode(prefs.getString('manual')!), data);
        expect(jsonDecode(prefs.getString('startup')!), data);
        expect(prefs.getString('unrelated'), 'keep');
      },
    );

    test(
      'missing, malformed and incomplete records do not suppress updates',
      () async {
        for (final value in [
          null,
          '',
          '{',
          '[]',
          'null',
          '{}',
          '{"date":"2026-09-10","currentVersion":"1"}',
        ]) {
          SharedPreferences.setMockInitialValues({'skip': ?value});
          expect(await store.read('skip'), isNull, reason: '$value');
        }
      },
    );
  });
}
