import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/preferences/hazuki_preference_keys.dart';
import 'source_runtime_host.dart';

/// Source-provided text localization and active-source cache invalidation.
class SourceLocalizationOperations {
  const SourceLocalizationOperations(this._runtimeHost);

  final SourceRuntimeHost _runtimeHost;

  void clearLocalizedSourceTextCaches() {
    final handle = _runtimeHost.activeHandle;
    handle.exploreCache.clearMemory();
    handle.facade.cache.clearCategoryTagGroupsMemoryCache();
  }

  String translateSourceText(String text, {String sourceKey = ''}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return text;
    }

    final resolvedSourceKey = sourceKey.trim().isEmpty
        ? _runtimeHost.activeSourceKey
        : sourceKey.trim();
    final handle = _runtimeHost.handleFor(resolvedSourceKey);
    final engine = handle.runtime.engine;
    if (engine == null) {
      return text;
    }

    final localeTag = _sourceTranslationLocaleTag(handle.session.prefs);
    if (localeTag == null) {
      return text;
    }

    try {
      final translated = engine.evaluate(
        'this.__hazuki_source.translation?.[${jsonEncode(localeTag)}]?.[${jsonEncode(trimmed)}]',
      );
      final value = translated?.toString().trim() ?? '';
      return value.isEmpty ? text : value;
    } catch (_) {
      return text;
    }
  }

  String? _sourceTranslationLocaleTag(SharedPreferences? prefs) {
    final saved = prefs?.getString(hazukiLocalePreferenceKey);
    final languageCode = switch (saved) {
      'zh' => 'zh',
      'en' => 'en',
      _ => PlatformDispatcher.instance.locale.languageCode,
    };
    return languageCode == 'zh' ? 'zh_CN' : null;
  }
}
