import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'software_update_reminder_policy.dart';

abstract interface class SoftwareUpdateReminderStore {
  Future<SoftwareUpdateReminder?> read(String key);
  Future<void> write(String key, SoftwareUpdateReminder reminder);
}

class SharedPreferencesSoftwareUpdateReminderStore
    implements SoftwareUpdateReminderStore {
  const SharedPreferencesSoftwareUpdateReminderStore();

  @override
  Future<SoftwareUpdateReminder?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final date = map['date']?.toString();
      final currentVersion = map['currentVersion']?.toString();
      final latestVersion = map['latestVersion']?.toString();
      if (date == null || currentVersion == null || latestVersion == null) {
        return null;
      }
      return SoftwareUpdateReminder(
        date: date,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, SoftwareUpdateReminder reminder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'date': reminder.date,
        'currentVersion': reminder.currentVersion,
        'latestVersion': reminder.latestVersion,
      }),
    );
  }
}
