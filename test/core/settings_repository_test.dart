import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsRepository notification preferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('all granular notification toggles default to true', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      expect(repo.notificationsEnabled(), isTrue);
      expect(repo.taskDailyDigestEnabled(), isTrue);
      expect(repo.taskRemindersEnabled(), isTrue);
      expect(repo.taskPileupNudgeEnabled(), isTrue);
      expect(repo.medicationNotificationsEnabled(), isTrue);
      expect(repo.householdNotificationsEnabled(), isTrue);
    });

    test(
      'master switch false disables all child getters without overwriting stored values',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = SettingsRepository(prefs);

        await repo.setTaskDailyDigestEnabled(true);
        await repo.setTaskRemindersEnabled(false);
        await repo.setNotificationsEnabled(false);

        expect(repo.notificationsEnabled(), isFalse);
        expect(repo.taskDailyDigestEnabled(), isFalse);
        expect(repo.taskRemindersEnabled(), isFalse);
        expect(repo.taskPileupNudgeEnabled(), isFalse);
        expect(repo.medicationNotificationsEnabled(), isFalse);
        expect(repo.householdNotificationsEnabled(), isFalse);

        // Raw stored values remain intact when respectMaster is false
        expect(repo.taskDailyDigestEnabled(respectMaster: false), isTrue);
        expect(repo.taskRemindersEnabled(respectMaster: false), isFalse);

        // Re-enabling master switch restores stored child preferences
        await repo.setNotificationsEnabled(true);
        expect(repo.taskDailyDigestEnabled(), isTrue);
        expect(repo.taskRemindersEnabled(), isFalse);
        expect(repo.taskPileupNudgeEnabled(), isTrue);
      },
    );
  });
}
