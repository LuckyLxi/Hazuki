import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

String _script(String result) =>
    '''
Hazuki.registerSource({id:'website',version:'1.0.0',
  presentation:{dailyRecommendation:{mode:'plugin'}},
  dailyRecommendation:{load:async()=>{globalThis.loads=(globalThis.loads||0)+1;return $result;}},
  search:{load:async()=>{throw new Error('must not search authors');}},
  comic:{loadInfo:async()=>{throw new Error('must not fetch authors');},loadEp:async()=>({images:[]})}
});
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourcePluginManager manager;
  late SourceRuntimeAssembly assembly;
  late Directory directory;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp(
      'hazuki_website_recommendation_',
    );
    manager = SourcePluginManager(
      directory: () async => directory,
      legacyDirectories: [],
    );
    assembly = SourceRuntimeAssembly(
      pluginManager: manager,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    );
    await assembly.runtimeRegistry.loadActiveSourcePreference();
  });
  tearDown(() async {
    assembly.dispose();
    manager.dispose();
    await directory.delete(recursive: true);
  });

  for (final count in [0, 1, 3, 12]) {
    test(
      'real runtime reuses $count site items in-session and fetches again after restart',
      () async {
        final items = List.generate(
          count,
          (index) => {
            'id': 'comic-$index',
            'title': 'Comic $index',
            'cover': 'https://example.com/cover-$index.jpg',
            'imageUrl': 'https://example.com/banner-$index.jpg',
            'bannerTitle': 'Website pick $index',
            'caption': 'Editor recommendation $index',
            'subTitle': 'Comic subtitle $index',
            'sourceKey': 'foreign_source',
          },
        );
        await manager.importPackage(utf8.encode(_script(jsonEncode(items))));
        await assembly.runtimeRegistry.ensureInitialized(sourceKey: 'website');
        final gateway = assembly.gateways.dailyRecommendation;
        expect(gateway.supportsDailyRecommendation, isTrue);
        expect(
          gateway.dailyRecommendationForSource('website')!.mode,
          DailyRecommendationMode.plugin,
        );
        final cacheStore =
            SharedPreferencesDiscoverDailyRecommendationCacheStore();
        final service = DiscoverDailyRecommendationService(
          source: gateway,
          cacheStore: cacheStore,
        );
        addTearDown(service.dispose);
        final state = await service.ensurePrepared(enabled: true);
        expect(state.recommendations, hasLength(count));
        expect(
          state.recommendations.map((e) => e.comic.id),
          items.map((e) => e['id']),
        );
        expect(
          state.recommendations.map((e) => e.author),
          items.map((e) => e['caption']),
        );
        expect(
          state.recommendations.every((e) => e.comic.sourceKey == 'website'),
          isTrue,
        );
        if (count > 0) {
          expect(state.recommendations.first.comic.cover, items.first['cover']);
          expect(state.recommendations.first.comic.title, items.first['title']);
          expect(
            state.recommendations.first.comic.subTitle,
            items.first['subTitle'],
          );
          expect(
            state.recommendations.first.displayTitle,
            items.first['bannerTitle'],
          );
          expect(
            state.recommendations.first.displayImageUrl,
            items.first['imageUrl'],
          );
        }
        final restored = DiscoverDailyRecommendationService(
          source: gateway,
          cacheStore: cacheStore,
        );
        addTearDown(restored.dispose);
        final cached = await restored.ensurePrepared(enabled: true);
        expect(cached.recommendations, hasLength(count));
        if (count > 0) {
          expect(
            cached.recommendations.first.imageUrl,
            items.first['imageUrl'],
          );
          expect(
            cached.recommendations.first.bannerTitle,
            items.first['bannerTitle'],
          );
        }
        expect(
          assembly.testing
              .handleFor('website')
              .runtime
              .engine!
              .evaluate('globalThis.loads'),
          1,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('discover_daily_recommendation_cache_website'),
          isNull,
        );
        final nextSession = DiscoverDailyRecommendationService(source: gateway);
        addTearDown(nextSession.dispose);
        expect(
          (await nextSession.ensurePrepared(enabled: true)).recommendations,
          hasLength(count),
        );
        expect(
          assembly.testing
              .handleFor('website')
              .runtime
              .engine!
              .evaluate('globalThis.loads'),
          2,
        );
      },
    );
  }

  test('legacy recommendations fall back to comic title and cover', () async {
    await manager.importPackage(
      utf8.encode(
        _script('[{id:"a",title:"Comic A",cover:"https://example.com/a.jpg"}]'),
      ),
    );
    await assembly.runtimeRegistry.ensureInitialized(sourceKey: 'website');
    final service = DiscoverDailyRecommendationService(
      source: assembly.gateways.dailyRecommendation,
    );
    addTearDown(service.dispose);
    final entry = (await service.ensurePrepared(
      enabled: true,
    )).recommendations.single;
    expect(entry.bannerTitle, isEmpty);
    expect(entry.displayTitle, 'Comic A');
    expect(entry.displayImageUrl, 'https://example.com/a.jpg');
    expect(entry.author, isEmpty);
  });

  test('banner-only images never become comic covers', () async {
    await manager.importPackage(
      utf8.encode(
        _script(
          '[{id:"a",title:"Comic A",bannerTitle:"Weekly pick",'
          'imageUrl:"https://example.com/banner.jpg"}]',
        ),
      ),
    );
    final entry =
        (await assembly.gateways.dailyRecommendation.loadDailyRecommendations(
          sourceKey: 'website',
        )).single;
    expect(entry.comic.id, 'a');
    expect(entry.comic.title, 'Comic A');
    expect(entry.comic.cover, isEmpty);
    expect(entry.bannerTitle, 'Weekly pick');
    expect(entry.imageUrl, 'https://example.com/banner.jpg');
  });

  test('plugin mode requires a callable loader at installation', () async {
    await expectLater(
      manager.importPackage(
        utf8.encode(
          _script('[]').replaceFirst(
            'dailyRecommendation:{load:async()=>{globalThis.loads=(globalThis.loads||0)+1;return [];}}',
            'dailyRecommendation:{}',
          ),
        ),
      ),
      throwsA(isA<SourcePluginException>()),
    );
    expect(manager.installed, isEmpty);
  });

  for (final result in [
    '{}',
    '[null]',
    '[{"id":"a","title":"A"}]',
    '[{"id":"a","title":"A","cover":123}]',
    '[{"id":"a","title":"A","cover":"a.jpg","bannerTitle":123}]',
  ]) {
    test('rejects malformed site recommendation response: $result', () async {
      await manager.importPackage(utf8.encode(_script(result)));
      await expectLater(
        assembly.gateways.dailyRecommendation.loadDailyRecommendations(
          sourceKey: 'website',
        ),
        throwsFormatException,
      );
    });
  }
}
