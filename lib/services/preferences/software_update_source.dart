import 'package:shared_preferences/shared_preferences.dart';

import 'hazuki_preference_keys.dart';

enum SoftwareUpdateSource {
  jsDelivr('jsdelivr'),
  github('github'),
  ghproxy('ghproxy');

  const SoftwareUpdateSource(this.preferenceValue);

  final String preferenceValue;

  static SoftwareUpdateSource fromPreference(String? value) {
    return SoftwareUpdateSource.values.firstWhere(
      (source) => source.preferenceValue == value,
      orElse: () => SoftwareUpdateSource.jsDelivr,
    );
  }
}

Future<SoftwareUpdateSource> loadSoftwareUpdateSourcePreference() async {
  final prefs = await SharedPreferences.getInstance();
  return SoftwareUpdateSource.fromPreference(
    prefs.getString(hazukiSoftwareUpdateSourcePreferenceKey),
  );
}
