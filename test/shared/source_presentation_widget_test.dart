import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_registry.dart';
import 'package:hazuki/shared/source_presentation.dart';
import 'package:hazuki/widgets/source_comic_tags.dart';

void main() {
  testWidgets('historical tags remain visible while plugin buttons disappear', (
    tester,
  ) async {
    const entry = SourceCatalogEntry(
      key: 'custom',
      name: 'Custom',
      fileName: 'main.js',
      presentation: {
        'showComments': true,
        'showTags': true,
        'listTagGroups': ['Genre'],
        'buttons': [
          {'id': 'copyComicId', 'location': 'comicDetailInfo'},
        ],
        'enrichMissingTags': true,
      },
    );
    final registry = SourceRuntimeRegistry(
      allowedSources: [entry],
      activeSourceKey: () => 'custom',
      definitionFor: (_) => entry,
      loadActiveSourcePreference: () async {},
      activateSource: (_) async {},
      ensureInitialized: ({sourceKey}) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    )..historicalPresentationFor = (_) => entry.presentation;
    addTearDown(registry.dispose);
    await tester.pumpWidget(
      SourcePresentationScope(
        registry: registry,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Column(
              children: [
                if (sourceCommentsEnabled('custom', context: context))
                  const Text('Comments entry'),
                const SourceComicTags(sourceKey: 'custom', tags: ['Saved tag']),
                if (sourceButton(
                      'custom',
                      'copyComicId',
                      SourcePluginButtonLocation.comicDetailInfo,
                      context: context,
                    ) !=
                    null)
                  const Text('Plugin action'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Saved tag'), findsOneWidget);
    expect(find.text('Plugin action'), findsOneWidget);
    expect(find.text('Comments entry'), findsOneWidget);
    registry.replaceCatalog([]);
    await tester.pump();
    expect(find.text('Saved tag'), findsOneWidget);
    expect(find.text('Plugin action'), findsNothing);
    expect(find.text('Comments entry'), findsNothing);
    expect(registry.displayPresentationFor('custom')['showComments'], isNull);
    expect(registry.presentationFor('custom'), isEmpty);
    expect(
      registry.displayPresentationFor('custom')['enrichMissingTags'],
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
