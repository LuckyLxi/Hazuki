import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/source_prefs_keys.dart';
import '../models/source_contract_models.dart';
import 'source_runtime_coordinator.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_registry.dart';
import 'source_secure_session_storage.dart';

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
  }) : _catalog = List.unmodifiable(catalog),
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
    );
  }

  final List<SourceCatalogEntry> _catalog;
  final SourceSecureSessionStorage _secureSessionStorage;
  final Future<void> Function(String sourceKey) _ensureSourceInitialized;
  final String? Function(String sourceKey) _currentAccountForSource;
  final bool Function(String sourceKey) _isLoggedForSource;

  late final SourceRuntimeCoordinator<SourceRuntimeHandle> _coordinator;
  late final SourceRuntimeRegistry runtimeRegistry;

  List<SourceCatalogEntry> get catalog => _catalog;
  String get activeSourceKey => _coordinator.activeSourceKey;
  SourceRuntimeHandle get activeHandle => _coordinator.activeHandle;

  SourceRuntimeHandle handleFor(String sourceKey) =>
      _coordinator.handleFor(sourceKey);

  SourceCatalogEntry definitionFor(String sourceKey) =>
      _coordinator.definitionFor(sourceKey);

  String normalize(String sourceKey) => _coordinator.normalize(sourceKey);

  Future<void> loadActiveSourcePreference() async {
    SharedPreferences? loadedPreferences;
    await _coordinator.loadActiveSourcePreference(
      readSavedSourceKey: () async {
        final prefs = await activeHandle.session.ensurePrefs();
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

  SourceRuntimeHandle? remove(String sourceKey) =>
      _coordinator.remove(sourceKey);

  /// Publishes changes initiated by an active runtime handle.
  void notifyActiveRuntimeChanged(String sourceKey) {
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
  );

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
