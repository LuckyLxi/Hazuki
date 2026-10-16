import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/category/source_category_capability.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test(
    'category requests preserve empty options and defer missing defaults to the plugin',
    () async {
      final host = _createHost();
      addTearDown(host.dispose);
      final engine = SourceScriptEngine(
        timeout: 5000,
        hostPromiseRejectionHandler: (_) {},
      );
      host.activeHandle.runtime.engine = engine;
      engine.evaluate('''
globalThis.__hazuki_source = {categoryComics: {
  optionList: [{options: ['-All', 'japan-Japan']}, {options: ['score-Score']}],
  load: (category, param, options, page) => {
    globalThis.lastRequest = {category, param, options, page};
    return {comics: [], maxPage: 1};
  }
}};
''');
      final capability = SourceCategoryCapability(
        runtimeHost: host,
        translateSourceText: (text, {sourceKey = ''}) => text,
        parseExploreComics: (_, {sourceKey = ''}) => [],
      );
      final groups = await capability.loadOptionGroupsByViewMore(
        viewMoreUrl: 'category:genre',
      );
      expect(groups.first.first.value, '');
      expect(groups.first.first.label, 'All');
      await capability.loadComicsByViewMore(
        viewMoreUrl: 'category:genre',
        page: 1,
      );
      expect(
        jsonDecode(
          engine.evaluate('JSON.stringify(lastRequest)') as String,
        )['options'],
        [],
      );
      await capability.loadComicsByViewMore(
        viewMoreUrl: 'category:genre',
        page: 2,
        orders: ['', ' score '],
      );
      final request =
          jsonDecode(engine.evaluate('JSON.stringify(lastRequest)') as String)
              as Map;
      expect(request['options'], ['', 'score']);
      expect(request['page'], 2);
    },
  );
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
