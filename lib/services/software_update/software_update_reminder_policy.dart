class SoftwareUpdateReminder {
  const SoftwareUpdateReminder({
    required this.date,
    required this.currentVersion,
    required this.latestVersion,
  });

  final String date;
  final String currentVersion;
  final String latestVersion;
}

/// A dismissal applies only to the same version pair on the same local day.
class SoftwareUpdateReminderPolicy {
  const SoftwareUpdateReminderPolicy({DateTime Function() now = DateTime.now})
    : _now = now;

  final DateTime Function() _now;

  bool shouldSkip({
    required SoftwareUpdateReminder? reminder,
    required String currentVersion,
    required String latestVersion,
  }) =>
      reminder != null &&
      reminder.date == _today() &&
      reminder.currentVersion == currentVersion &&
      reminder.latestVersion == latestVersion;

  SoftwareUpdateReminder remindLaterToday({
    required String currentVersion,
    required String latestVersion,
  }) => SoftwareUpdateReminder(
    date: _today(),
    currentVersion: currentVersion,
    latestVersion: latestVersion,
  );

  String _today() {
    final now = _now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
