import 'package:flutter/foundation.dart';

import '../models/source_contract_models.dart';

class SourceRuntimeRegistry extends ChangeNotifier {
  SourceRuntimeRegistry({
    required List<SourceCatalogEntry> allowedSources,
    required String Function() activeSourceKey,
    required SourceCatalogEntry Function(String sourceKey) definitionFor,
    required Future<void> Function() loadActiveSourcePreference,
    required Future<void> Function(String sourceKey) activateSource,
    required Future<void> Function({String? sourceKey}) ensureInitialized,
    required String? Function(String sourceKey) currentAccountForSource,
    required bool Function(String sourceKey) isLoggedForSource,
  }) : _allowedSources = List.unmodifiable(allowedSources),
       _activeSourceKey = activeSourceKey,
       _definitionFor = definitionFor,
       _loadActiveSourcePreference = loadActiveSourcePreference,
       _activateSource = activateSource,
       _ensureInitialized = ensureInitialized,
       _currentAccountForSource = currentAccountForSource,
       _isLoggedForSource = isLoggedForSource;

  final List<SourceCatalogEntry> _allowedSources;
  final String Function() _activeSourceKey;
  final SourceCatalogEntry Function(String sourceKey) _definitionFor;
  final Future<void> Function() _loadActiveSourcePreference;
  final Future<void> Function(String sourceKey) _activateSource;
  final Future<void> Function({String? sourceKey}) _ensureInitialized;
  final String? Function(String sourceKey) _currentAccountForSource;
  final bool Function(String sourceKey) _isLoggedForSource;

  List<SourceCatalogEntry> get allowedSources => _allowedSources;
  String get activeSourceKey => _activeSourceKey();
  SourceCatalogEntry activeSourceDefinition() => definitionFor(activeSourceKey);
  SourceCatalogEntry definitionFor(String sourceKey) =>
      _definitionFor(sourceKey);
  bool isAllowedSourceKey(String sourceKey) {
    final normalized = sourceKey.trim();
    return allowedSources.any((entry) => entry.normalizedKey == normalized);
  }

  Future<void> loadActiveSourcePreference() => _loadActiveSourcePreference();
  Future<void> activateSource(String sourceKey) => _activateSource(sourceKey);
  Future<void> ensureInitialized({String? sourceKey}) =>
      _ensureInitialized(sourceKey: sourceKey);
  String? currentAccountForSource(String sourceKey) =>
      _currentAccountForSource(sourceKey);
  bool isLoggedForSource(String sourceKey) => _isLoggedForSource(sourceKey);

  void notifyChanged() => notifyListeners();
}
