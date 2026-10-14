import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/preferences/hazuki_preference_keys.dart';

/// Matches the app's supported locales, including its English system fallback.
String sourcePluginLocaleTag(SharedPreferences? prefs) {
  final saved = prefs?.getString(hazukiLocalePreferenceKey);
  final language = saved == 'zh' || saved == 'en'
      ? saved
      : basicLocaleListResolution(
          WidgetsBinding.instance.platformDispatcher.locales,
          const [Locale('en'), Locale('zh')],
        ).languageCode;
  return language == 'zh' ? 'zh_CN' : 'en_US';
}

Iterable<String> _localeKeys(String locale) sync* {
  var normalized = locale.replaceAll('-', '_');
  final language = normalized.split('_').first;
  // The app exposes language-only locales; retain legacy region dictionaries.
  if (normalized == language) {
    normalized = switch (language) {
      'zh' => 'zh_CN',
      'en' => 'en_US',
      _ => language,
    };
  }
  yield normalized;
  yield normalized.replaceAll('_', '-');
  yield language;
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

/// Resolves a language map or a string translated by the plugin dictionary.
String localizeSourcePluginText(
  Object? text,
  String locale, {
  Object? translation,
  String fallback = '',
}) {
  if (text is Map) {
    for (final key in {..._localeKeys(locale), 'en_US', 'en-US', 'en'}) {
      final value = _text(text[key]);
      if (value != null) return value;
    }
    for (final value in text.values) {
      final result = _text(value);
      if (result != null) return result;
    }
    return fallback;
  }
  final original = text?.toString() ?? fallback;
  if (translation is Map) {
    for (final key in _localeKeys(locale)) {
      final dictionary = translation[key];
      if (dictionary is! Map) continue;
      final value = _text(dictionary[original.trim()]);
      if (value != null) return value;
    }
  }
  return original;
}
