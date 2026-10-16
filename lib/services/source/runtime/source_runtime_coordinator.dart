import '../models/source_contract_models.dart';

abstract interface class SourceRuntimeResource {
  String get sourceKey;
  void requestDispose();
}

class SourceRuntimeCoordinator<T extends SourceRuntimeResource> {
  SourceRuntimeCoordinator({
    required List<SourceCatalogEntry> catalog,
    required String defaultSourceKey,
    required T Function(String sourceKey) createHandle,
    required void Function() onActiveSourceChanged,
  }) : _catalog = List.unmodifiable(catalog),
       _defaultSourceKey = defaultSourceKey,
       _createHandle = createHandle,
       _onActiveSourceChanged = onActiveSourceChanged,
       _activeSourceKey = defaultSourceKey;

  List<SourceCatalogEntry> _catalog;
  final String _defaultSourceKey;
  final T Function(String sourceKey) _createHandle;
  final void Function() _onActiveSourceChanged;
  final Map<String, T> _handles = {};
  String _activeSourceKey;
  Future<void> _activationTail = Future.value();

  List<SourceCatalogEntry> get catalog => _catalog;
  String get activeSourceKey => _activeSourceKey;
  T get activeHandle => handleFor(_activeSourceKey);

  SourceCatalogEntry definitionFor(String sourceKey) {
    final normalized = normalize(sourceKey);
    return _catalog.firstWhere((entry) => entry.normalizedKey == normalized);
  }

  String normalize(String sourceKey) {
    final normalized = sourceKey.trim().isEmpty
        ? (_activeSourceKey.isNotEmpty ? _activeSourceKey : _defaultSourceKey)
        : sourceKey.trim();
    if (!_catalog.any((entry) => entry.normalizedKey == normalized)) {
      throw Exception('plugin_not_installed:$normalized');
    }
    return normalized;
  }

  bool isAllowed(String sourceKey) {
    final normalized = sourceKey.trim();
    return _catalog.any((entry) => entry.normalizedKey == normalized);
  }

  T handleFor(String sourceKey) {
    final normalized = normalize(sourceKey);
    return _handles.putIfAbsent(normalized, () => _createHandle(normalized));
  }

  T? existingHandle(String sourceKey) => _handles[sourceKey];

  Future<void> loadActiveSourcePreference({
    required Future<String?> Function() readSavedSourceKey,
    required Future<void> Function(String sourceKey) persistSourceKey,
  }) {
    return _serialize(() async {
      final saved = (await readSavedSourceKey())?.trim() ?? '';
      if (saved.isNotEmpty && isAllowed(saved)) {
        _activeSourceKey = saved;
        return;
      }
      _activeSourceKey = isAllowed(_defaultSourceKey)
          ? _defaultSourceKey
          : (_catalog.firstOrNull?.normalizedKey ?? '');
      if (saved.isNotEmpty) await persistSourceKey(_activeSourceKey);
    });
  }

  Future<void> activate(
    String sourceKey, {
    required Future<void> Function(T nextHandle) persistSelection,
  }) {
    final normalized = normalize(sourceKey);
    return _serialize(() async {
      if (normalized == _activeSourceKey) return;
      final previousSourceKey = _activeSourceKey;
      final previousHandle = _handles[previousSourceKey];
      final nextHandle = handleFor(normalized);
      await persistSelection(nextHandle);
      _activeSourceKey = normalized;
      if (identical(_handles[previousSourceKey], previousHandle)) {
        _handles.remove(previousSourceKey);
        previousHandle?.requestDispose();
      }
      _onActiveSourceChanged();
    });
  }

  T? remove(String sourceKey) {
    final removed = _handles.remove(normalize(sourceKey));
    removed?.requestDispose();
    return removed;
  }

  Future<void> replaceCatalog(
    List<SourceCatalogEntry> catalog, {
    Future<void> Function(String activeSourceKey)? beforeReplace,
  }) => _serialize(() async {
    final previous = {for (final entry in _catalog) entry.key: entry};
    final next = {for (final entry in catalog) entry.key: entry};
    final nextActiveSourceKey = next.containsKey(_activeSourceKey)
        ? _activeSourceKey
        : (catalog.firstOrNull?.normalizedKey ?? '');
    await beforeReplace?.call(nextActiveSourceKey);
    for (final key in _handles.keys.toList()) {
      if (!next.containsKey(key) ||
          next[key]?.pluginDirectory != previous[key]?.pluginDirectory ||
          next[key]?.pluginVersion != previous[key]?.pluginVersion) {
        _handles.remove(key)?.requestDispose();
      }
    }
    _catalog = List.unmodifiable(catalog);
    _activeSourceKey = nextActiveSourceKey;
    _onActiveSourceChanged();
  });

  /// Disposes a source's current resources and creates a replacement handle.
  ///
  /// When [expectedHandle] is supplied, a handle replaced by another caller is
  /// retained. This makes concurrent recovery requests converge on one runtime.
  T recreate(String sourceKey, {T? expectedHandle}) {
    final normalized = normalize(sourceKey);
    final current = _handles[normalized];
    if (expectedHandle != null && !identical(current, expectedHandle)) {
      return handleFor(normalized);
    }
    _handles.remove(normalized)?.requestDispose();
    final replacement = handleFor(normalized);
    if (normalized == _activeSourceKey) {
      _onActiveSourceChanged();
    }
    return replacement;
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _activationTail.then<void>(
      (_) => operation(),
      onError: (_, _) => operation(),
    );
    _activationTail = next;
    return next;
  }
}
