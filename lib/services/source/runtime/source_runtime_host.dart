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
import '../interaction/source_ui_service.dart';
import 'source_task_registry.dart';
import '../models/source_task.dart';

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
      retainOnSourceChange: (key) =>
          _readerSessions.any((session) => session.sourceKey == key) ||
          _downloadSessions.keys.any((session) => session.sourceKey == key),
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
  final SourceTaskRegistry tasks = SourceTaskRegistry();
  final String serviceTaskOwnerId = createSourceTaskId();
  final Set<SourceReaderSession> _readerSessions = {};

  final Map<SourceDownloadSession, SourceRuntimeHandle> _downloadSessions = {};

  SourceDownloadSession acquireDownloadSession(String sourceKey) {
    if (sourceKey.trim().isNotEmpty &&
        !_catalog.any((entry) => entry.normalizedKey == sourceKey.trim())) {
      throw SourceTaskCancelled(
        createSourceTaskId(),
        SourceTaskStopReason.pluginDisabled,
      );
    }
    final key = normalize(sourceKey);
    final handle = handleFor(key);
    tasks.checkResourceActive(handle);
    late final SourceDownloadSession session;
    session = SourceDownloadSession(key, () {
      final held = _downloadSessions.remove(session);
      if (held != null &&
          isCurrentHandle(held) &&
          key != activeSourceKey &&
          !_readerSessions.any((entry) => entry.sourceKey == key) &&
          !_downloadSessions.keys.any((entry) => entry.sourceKey == key) &&
          session.cancellation.reason != SourceTaskStopReason.pluginDisabled &&
          session.cancellation.reason != SourceTaskStopReason.pluginUpdated &&
          session.cancellation.reason != SourceTaskStopReason.runtimeClosed) {
        _coordinator.remove(key);
      }
    }, resource: () => _downloadSessions[session]);
    _downloadSessions[session] = handle;
    return session;
  }

  /// Only the existing, explicit chapter recovery path may transfer a lease.
  void transferDownloadSession(
    SourceTaskOrigin? origin,
    SourceRuntimeHandle previous,
    SourceRuntimeHandle replacement,
  ) {
    final session = origin?.downloadSession;
    if (session == null) return;
    session.checkActive();
    if (!identical(_downloadSessions[session], previous) ||
        !isCurrentHandle(replacement)) {
      throw StateError('source_download_session_mismatch');
    }
    tasks.checkResourceActive(replacement);
    _downloadSessions[session] = replacement;
  }

  SourceReaderSession acquireReaderSession(String sourceKey) {
    final key = normalize(sourceKey);
    tasks.checkResourceActive(handleFor(key));
    late final SourceReaderSession session;
    session = SourceReaderSession(key, () {
      _readerSessions.remove(session);
      final reason = session.cancellation.reason;
      final retiring =
          reason == SourceTaskStopReason.pluginDisabled ||
          reason == SourceTaskStopReason.pluginUpdated ||
          reason == SourceTaskStopReason.runtimeClosed;
      if (!retiring &&
          key != activeSourceKey &&
          !_readerSessions.any((entry) => entry.sourceKey == key) &&
          !_downloadSessions.keys.any((entry) => entry.sourceKey == key)) {
        _coordinator.remove(key);
      }
    });
    _readerSessions.add(session);
    return session;
  }

  void checkReaderSession(String key, SourceTaskOrigin? origin) {
    final download = origin?.downloadSession;
    if (download != null) {
      download.checkActive();
      final held = _downloadSessions[download];
      if (download.sourceKey != key || held == null || !isCurrentHandle(held)) {
        throw StateError('source_download_session_mismatch');
      }
      tasks.checkResourceActive(held);
    }
    final session = origin?.readerSession;
    if (session == null) return;
    session.checkActive();
    if (session.sourceKey != key || !_readerSessions.contains(session)) {
      throw StateError('source_reader_session_mismatch');
    }
  }

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

  Future<void> activateSource(String sourceKey) async {
    final previous = optionalActiveHandle;
    if (normalize(sourceKey) != activeSourceKey) {
      SourceUiService.instance.cancelPlugin(activeSourceKey, 'sourceChanged');
    }
    await _coordinator.activate(
      sourceKey,
      persistSelection: (nextHandle) async {
        final prefs = await nextHandle.session.ensurePrefs();
        await prefs.setString(
          SourcePrefsKeys.activeSourceKey,
          nextHandle.sourceKey,
        );
      },
    );
    if (previous != null && activeSourceKey != previous.sourceKey) {
      await tasks.cancelResource(
        previous,
        SourceTaskStopReason.sourceChanged,
        includeServiceTasks: false,
      );
    }
  }

  Future<void> replaceCatalog(List<SourceCatalogEntry> catalog) async {
    final enabled = catalog.map((source) => source.normalizedKey).toSet();
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
        for (final handle in existingHandles.toList()) {
          final old = _catalog
              .where((entry) => entry.normalizedKey == handle.sourceKey)
              .firstOrNull;
          final next = catalog
              .where((entry) => entry.normalizedKey == handle.sourceKey)
              .firstOrNull;
          if (next == null ||
              old?.pluginVersion != next.pluginVersion ||
              old?.pluginDirectory != next.pluginDirectory) {
            final reason = next == null
                ? SourceTaskStopReason.pluginDisabled
                : SourceTaskStopReason.pluginUpdated;
            final stopped = tasks.retireResource(handle, reason);
            for (final session in _readerSessions.toList()) {
              if (session.sourceKey == handle.sourceKey) session.close(reason);
            }
            for (final entry in _downloadSessions.entries.toList()) {
              if (identical(entry.value, handle)) entry.key.close(reason);
            }
            await stopped;
          }
        }
        for (final old in _catalog) {
          if (!enabled.contains(old.normalizedKey)) {
            SourceUiService.instance.cancelPlugin(
              old.normalizedKey,
              'runtimeDisposed',
            );
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
    String? completingTaskId,
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
    tasks: tasks,
    canCacheImages: (handle) => isCurrentHandle(handle),
  )..pluginDirectory = definitionFor(sourceKey).pluginDirectory;

  void _notifyChanged() {
    notifyListeners();
    runtimeRegistry.notifyChanged();
  }

  @override
  void dispose() {
    for (final session in _readerSessions.toList()) {
      session.close(SourceTaskStopReason.runtimeClosed);
    }
    for (final session in _downloadSessions.keys.toList()) {
      session.close(SourceTaskStopReason.runtimeClosed);
    }
    tasks.dispose();
    for (final source in _catalog) {
      _coordinator.remove(source.key);
    }
    runtimeRegistry.dispose();
    super.dispose();
  }
}
