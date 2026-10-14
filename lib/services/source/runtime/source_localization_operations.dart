import '../plugins/source_plugin_localization.dart';
import 'source_runtime_host.dart';

/// Source-provided text localization and active-source cache invalidation.
class SourceLocalizationOperations {
  const SourceLocalizationOperations(this._runtimeHost);

  final SourceRuntimeHost _runtimeHost;

  void clearLocalizedSourceTextCaches() {
    for (final handle in _runtimeHost.existingHandles) {
      handle.exploreCache.clearMemory();
      handle.facade.cache.clearCategoryTagGroupsMemoryCache();
    }
  }

  String translateSourceText(String text, {String sourceKey = ''}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return text;
    }

    final resolvedSourceKey = sourceKey.trim().isEmpty
        ? _runtimeHost.activeSourceKey
        : sourceKey.trim();
    if (!_runtimeHost.runtimeRegistry.isAllowedSourceKey(resolvedSourceKey)) {
      return text;
    }
    final handle = _runtimeHost.handleFor(resolvedSourceKey);
    final engine = handle.runtime.engine;
    if (engine == null) {
      return text;
    }

    try {
      return localizeSourcePluginText(
        text,
        sourcePluginLocaleTag(handle.session.prefs),
        translation: engine.evaluate('this.__hazuki_source.translation ?? {}'),
      );
    } catch (_) {
      return text;
    }
  }
}
