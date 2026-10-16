import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/source_prefs_keys.dart';
import '../models/source_contract_models.dart';
import '../plugins/source_plugin_buttons.dart';
import 'source_runtime_coordinator.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_registry.dart';
import 'source_secure_session_storage.dart';
import '../../logging/app_log_store.dart';

/// Owns source selection and the lifetime of per-source runtime handles.
///
/// Source capabilities receive the active handle through the service façade;
/// this object deliberately keeps selection and handle disposal out of those
/// capabilities.
class SourceRuntimeHost extends ChangeNotifier {
  SourceRuntimeHost({
    required List<SourceCatalogEntry> catalog,
    required String defaultSourceKey,
    required SourceSecureSessionStorage secureSessionStorage,
    required Future<void> Function(String sourceKey) ensureSourceInitialized,
    required String? Function(String sourceKey) currentAccountForSource,
    required bool Function(String sourceKey) isLoggedForSource,
    AppLogStore? logStore,
    this.onRuntimeState,
  }) : _catalog = List.unmodifiable(catalog),
       logStore = logStore ?? AppLogStore(),
       _secureSessionStorage = secureSessionStorage,
       _ensureSourceInitialized = ensureSourceInitialized,
       _currentAccountForSource = currentAccountForSource,
       _isLoggedForSource = isLoggedForSource {
    _coordinator = SourceRuntimeCoordinator<SourceRuntimeHandle>(
      catalog: _catalog,
      defaultSourceKey: defaultSourceKey,
      createHandle: _createHandle,
      onActiveSourceChanged: _notifyChanged,
    );
    runtimeRegistry = SourceRuntimeRegistry(
      allowedSources: _catalog,
      activeSourceKey: () => activeSourceKey,
      definitionFor: definitionFor,
      loadActiveSourcePreference: loadActiveSourcePreference,
      activateSource: activateSource,
      ensureInitialized: ({String? sourceKey}) =>
          _ensureSourceInitialized(sourceKey ?? activeSourceKey),
      currentAccountForSource: _currentAccountForSource,
      isLoggedForSource: _isLoggedForSource,
      runtimePresentationFor: (key) =>
          _coordinator.existingHandle(key)?.runtime.sourceMeta?.presentation ??
          const {},
    );
  }

  List<SourceCatalogEntry> _catalog;
  final SourceSecureSessionStorage _secureSessionStorage;
  final Future<void> Function(String sourceKey) _ensureSourceInitialized;
  final String? Function(String sourceKey) _currentAccountForSource;
  final bool Function(String sourceKey) _isLoggedForSource;
  final AppLogStore logStore;
  final void Function(String, SourceRuntimeState)? onRuntimeState;

  late final SourceRuntimeCoordinator<SourceRuntimeHandle> _coordinator;
  late final SourceRuntimeRegistry runtimeRegistry;
  bool _preferenceLoaded = false;

  List<SourceCatalogEntry> get catalog => _catalog;
  String get activeSourceKey => _coordinator.activeSourceKey;
  bool get hasActiveSource => activeSourceKey.isNotEmpty;
  SourceRuntimeHandle? get optionalActiveHandle =>
      hasActiveSource ? activeHandle : null;
  bool feature(String key) =>
      hasActiveSource &&
      (optionalActiveHandle?.runtime.sourceMeta?.presentation[key] ??
              definitionFor(activeSourceKey).presentation[key]) ==
          true;
  bool get supportsDailyCheckIn {
    if (!hasActiveSource) return false;
    final buttons =
        optionalActiveHandle?.runtime.sourceMeta?.presentation['buttons'] ??
        definitionFor(activeSourceKey).presentation['buttons'];
    return feature('dailyCheckIn') ||
        SourcePluginButton.parseList(
          buttons,
        ).any((button) => button.id == 'checkIn' || button.id == 'autoCheckIn');
  }

  SourceRuntimeHandle get activeHandle => _coordinator.activeHandle;
  Iterable<SourceRuntimeHandle> get existingHandles => _catalog
      .map((source) => _coordinator.existingHandle(source.key))
      .whereType<SourceRuntimeHandle>();

  SourceRuntimeHandle handleFor(String sourceKey) =>
      _coordinator.handleFor(sourceKey);

  SourceCatalogEntry definitionFor(String sourceKey) =>
      _coordinator.definitionFor(sourceKey);

  String normalize(String sourceKey) => _coordinator.normalize(sourceKey);
  bool isCurrentHandle(SourceRuntimeHandle handle) =>
      identical(_coordinator.existingHandle(handle.sourceKey), handle);

  Future<void> loadActiveSourcePreference() async {
    SharedPreferences? loadedPreferences;
    await _coordinator.loadActiveSourcePreference(
      readSavedSourceKey: () async {
        final prefs = await SharedPreferences.getInstance();
        loadedPreferences = prefs;
        for (final source in _catalog) {
          final session = handleFor(source.key).session;
          session.prefs = prefs;
          await session.ensurePrefs();
        }
        return prefs.getString(SourcePrefsKeys.activeSourceKey);
      },
      persistSourceKey: (sourceKey) => loadedPreferences!.setString(
        SourcePrefsKeys.activeSourceKey,
        sourceKey,
      ),
    );
    _preferenceLoaded = true;
  }

  Future<void> activateSource(String sourceKey) {
    return _coordinator.activate(
      sourceKey,
      persistSelection: (nextHandle) async {
        final prefs = await nextHandle.session.ensurePrefs();
        await prefs.setString(
          SourcePrefsKeys.activeSourceKey,
          nextHandle.sourceKey,
        );
      },
    );
  }

  Future<void> replaceCatalog(List<SourceCatalogEntry> catalog) async {
    await _coordinator.replaceCatalog(
      catalog,
      beforeReplace: (nextSourceKey) async {
        if (_preferenceLoaded) {
          final prefs = await SharedPreferences.getInstance();
          final previous = prefs.getString(SourcePrefsKeys.activeSourceKey);
          try {
            if (!await prefs.setString(
              SourcePrefsKeys.activeSourceKey,
              nextSourceKey,
            )) {
              throw StateError('source_selection_not_saved');
            }
          } catch (_) {
            // SharedPreferences updates its memory cache before persisting.
            if (previous == null) {
              await prefs.remove(SourcePrefsKeys.activeSourceKey);
            } else {
              await prefs.setString(SourcePrefsKeys.activeSourceKey, previous);
            }
            rethrow;
          }
        }
        _catalog = List.unmodifiable(catalog);
        runtimeRegistry.replaceCatalog(catalog, notify: false);
      },
    );
  }

  SourceRuntimeHandle? remove(String sourceKey) =>
      _coordinator.remove(sourceKey);

  /// Rebuilds the source's network client and JavaScript runtime.
  SourceRuntimeHandle recreateSourceRuntime(
    String sourceKey, {
    SourceRuntimeHandle? expectedHandle,
  }) {
    final replacement = _coordinator.recreate(
      sourceKey,
      expectedHandle: expectedHandle,
    );
    return replacement;
  }

  /// Publishes changes initiated by an active runtime handle.
  void notifyActiveRuntimeChanged(String sourceKey) {
    final current = _coordinator.existingHandle(sourceKey);
    if (current != null) {
      onRuntimeState?.call(sourceKey, current.runtime.runtimeState);
    }
    if (activeSourceKey == sourceKey) {
      _notifyChanged();
    } else {
      runtimeRegistry.notifyChanged();
    }
  }

  SourceRuntimeHandle _createHandle(String sourceKey) => SourceRuntimeHandle(
    sourceKey: sourceKey,
    secureStorage: _secureSessionStorage,
    ensureInitialized: _ensureSourceInitialized,
    notifyRuntimeStateChanged: notifyActiveRuntimeChanged,
    appLogStore: logStore,
  )..pluginDirectory = definitionFor(sourceKey).pluginDirectory;

  void _notifyChanged() {
    notifyListeners();
    runtimeRegistry.notifyChanged();
  }

  @override
  void dispose() {
    for (final source in _catalog) {
      _coordinator.remove(source.key);
    }
    runtimeRegistry.dispose();
    super.dispose();
  }
}
