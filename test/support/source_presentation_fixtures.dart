import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/runtime/source_runtime_registry.dart';
import 'package:hazuki/shared/source_presentation.dart';

import 'source_catalog_fixtures.dart';

Widget withTestSourcePresentation(
  Widget child, {
  String activeSourceKey = 'jm',
  List<SourceCatalogEntry> catalog = hazukiAllowedSourceCatalog,
}) {
  final registry = SourceRuntimeRegistry(
    allowedSources: catalog,
    activeSourceKey: () => activeSourceKey,
    definitionFor: (key) => catalog.firstWhere((entry) => entry.key == key),
    loadActiveSourcePreference: () async {},
    activateSource: (_) async {},
    ensureInitialized: ({sourceKey}) async {},
    currentAccountForSource: (_) => null,
    isLoggedForSource: (_) => false,
  );
  addTearDown(registry.dispose);
  return SourcePresentationScope(registry: registry, child: child);
}
