import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const hazukiNoImageModePreferenceKey = 'advanced_no_image_mode';

final ValueNotifier<bool> hazukiNoImageModeNotifier = ValueNotifier<bool>(
  false,
);

Future<void> loadHazukiUiFlags() async {
  final prefs = await SharedPreferences.getInstance();
  hazukiNoImageModeNotifier.value =
      prefs.getBool(hazukiNoImageModePreferenceKey) ?? false;
}

Future<void> setHazukiNoImageMode(bool enabled) async {
  hazukiNoImageModeNotifier.value = enabled;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(hazukiNoImageModePreferenceKey, enabled);
}
