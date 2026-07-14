import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/category/source_category_capability.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  test('parses category and explore View More targets', () {
    expect(
      SourceCategoryCapability.parseCategoryViewMoreUrl('category:genre@hot'),
      (category: 'genre', param: 'hot'),
    );
    expect(
      SourceCategoryCapability.parseCategoryViewMoreUrl('category:genre@'),
      (category: 'genre', param: null),
    );
    expect(SourceCategoryCapability.parseCategoryViewMoreUrl('direct-value'), (
      category: 'direct-value',
      param: null,
    ));
    expect(SourceCategoryCapability.parseExploreViewMoreIndex('explore:2'), 2);
    expect(
      SourceCategoryCapability.parseExploreViewMoreIndex('explore:-1'),
      isNull,
    );
  });

  test('normalizes non-positive pages and delegates comic source keys', () {
    final requestedSourceKeys = <String>[];
    final capability = SourceCategoryCapability(
      runtimeHost: _createHost(),
      translateSourceText: (text, {sourceKey = ''}) => text,
      parseExploreComics: (comics, {sourceKey = ''}) {
        requestedSourceKeys.add(sourceKey);
        return [
          ExploreComic(
            id: 'comic',
            title: 'Comic',
            subTitle: '',
            cover: '',
            sourceKey: sourceKey.isEmpty ? 'jm' : sourceKey,
          ),
        ];
      },
    );

    expect(SourceCategoryCapability.normalizePageForTesting(0), 1);
    expect(SourceCategoryCapability.normalizePageForTesting(-3), 1);
    expect(SourceCategoryCapability.normalizePageForTesting(4), 4);

    final result = capability.parseCategoryComicsResultForTesting({
      'comics': [
        {'id': 'comic'},
      ],
      'maxPage': '7',
    });
    expect(requestedSourceKeys, ['']);
    expect(result.comics.single.sourceKey, 'jm');
    expect(result.maxPage, 7);
  });
}

SourceRuntimeHost _createHost() {
  return SourceRuntimeHost(
    catalog: const [
      SourceCatalogEntry(key: 'jm', name: 'JM', fileName: 'jm.js'),
    ],
    defaultSourceKey: 'jm',
    secureSessionStorage: MemorySourceSecureSessionStorage(),
    ensureSourceInitialized: (_) async {},
    currentAccountForSource: (_) => null,
    isLoggedForSource: (_) => false,
  );
}
