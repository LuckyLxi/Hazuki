import 'package:flutter/foundation.dart';

import '../models/source_contract_models.dart';
import '../plugins/source_presentation_metadata.dart';

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
    SourcePresentationReader runtimePresentationFor = emptySourcePresentation,
  }) : _allowedSources = List.unmodifiable(allowedSources),
       _activeSourceKey = activeSourceKey,
       _definitionFor = definitionFor,
       _loadActiveSourcePreference = loadActiveSourcePreference,
       _activateSource = activateSource,
       _ensureInitialized = ensureInitialized,
       _currentAccountForSource = currentAccountForSource,
       _isLoggedForSource = isLoggedForSource,
       _runtimePresentationFor = runtimePresentationFor;

  List<SourceCatalogEntry> _allowedSources;
  final String Function() _activeSourceKey;
  final SourceCatalogEntry Function(String sourceKey) _definitionFor;
  final Future<void> Function() _loadActiveSourcePreference;
  final Future<void> Function(String sourceKey) _activateSource;
  final Future<void> Function({String? sourceKey}) _ensureInitialized;
  final String? Function(String sourceKey) _currentAccountForSource;
  final bool Function(String sourceKey) _isLoggedForSource;
  final SourcePresentationReader _runtimePresentationFor;
  Future<void> Function()? prepareCatalog;
  SourcePresentationReader historicalPresentationFor = emptySourcePresentation;

  Map<String, dynamic> presentationFor(String sourceKey) =>
      isAllowedSourceKey(sourceKey)
      ? {
          ...definitionFor(sourceKey.trim()).presentation,
          ..._runtimePresentationFor(sourceKey.trim()),
        }
      : const {};

  Map<String, dynamic> displayPresentationFor(String sourceKey) =>
      isAllowedSourceKey(sourceKey)
      ? presentationFor(sourceKey)
      : historicalSourcePresentation(
          historicalPresentationFor(sourceKey.trim()),
        );

  List<SourceCatalogEntry> get allowedSources => List.unmodifiable(
    _allowedSources.map((source) {
      final runtime = _runtimePresentationFor(source.normalizedKey);
      return runtime.isEmpty
          ? source
          : source.withPresentation({...source.presentation, ...runtime});
    }),
  );
  String? get activeSourceKey =>
      _activeSourceKey().isEmpty ? null : _activeSourceKey();
  bool get hasActiveSource => activeSourceKey != null;
  void replaceCatalog(List<SourceCatalogEntry> sources, {bool notify = true}) {
    _allowedSources = List.unmodifiable(sources);
    if (notify) notifyListeners();
  }

  SourceCatalogEntry? activeSourceDefinition() =>
      activeSourceKey == null ? null : definitionFor(activeSourceKey!);
  SourceCatalogEntry definitionFor(String sourceKey) =>
      _definitionFor(sourceKey);
  bool isAllowedSourceKey(String sourceKey) {
    final normalized = sourceKey.trim();
    return _allowedSources.any((entry) => entry.normalizedKey == normalized);
  }

  Future<void> loadActiveSourcePreference() async {
    await prepareCatalog?.call();
    await _loadActiveSourcePreference();
  }

  Future<void> activateSource(String sourceKey) => _activateSource(sourceKey);
  Future<void> ensureInitialized({String? sourceKey}) =>
      _ensureInitialized(sourceKey: sourceKey);
  String? currentAccountForSource(String sourceKey) =>
      _currentAccountForSource(sourceKey);
  bool isLoggedForSource(String sourceKey) => _isLoggedForSource(sourceKey);

  void notifyChanged() => notifyListeners();
}
