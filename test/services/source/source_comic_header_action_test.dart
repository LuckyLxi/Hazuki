import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/comic/comic_details_capability.dart';
import 'package:hazuki/services/source/comic/source_comic_details_cache.dart';
import 'package:hazuki/services/source/plugins/source_plugin_buttons.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceComicDetailsCache cache;
  late SourceComicDetailsCapability capability;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'arbitrary',
          name: 'Any plugin',
          fileName: 'any.js',
        ),
        SourceCatalogEntry(
          key: 'other',
          name: 'Other plugin',
          fileName: 'other.js',
        ),
      ],
      defaultSourceKey: 'arbitrary',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    cache = SourceComicDetailsCache(runtimeHost: host);
    capability = SourceComicDetailsCapability(
      runtimeHost: host,
      cache: cache,
      reloginCoordinator: SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {},
      ),
      translateSourceText: (text, {sourceKey = ''}) => text,
    );
    addTearDown(host.dispose);
  });

  SourceScriptEngine engineFor(String key) {
    final engine = SourceScriptEngine(hostPromiseRejectionHandler: (_) {});
    host.handleFor(key).runtime.engine = engine;
    return engine;
  }

  test(
    'header actions call the target plugin even when another source is active',
    () async {
      final active = engineFor('arbitrary');
      active.evaluate(
        'globalThis.__hazuki_source={comic:{onHeaderAction:()=>{throw "wrong_source"}}}',
      );
      final target = engineFor('other');
      await target.evaluate(
        'globalThis.calls=[]; globalThis.__hazuki_source={comic:{onHeaderAction:async(id,action)=>{calls.push([id,action]);}}}',
      );
      final result = await capability.runComicHeaderAction(
        comicId: 'comic"id',
        actionId: 'like',
        sourceKey: 'other',
      );
      expect(result.headerStats, isNull);
      expect(result.reload, isFalse);
      expect(
        await target.evaluate('JSON.stringify(calls)'),
        '[["comic\\"id","like"]]',
      );
      expect(host.activeSourceKey, 'arbitrary');
    },
  );

  test('returned header content replaces the cached details', () async {
    final engine = engineFor('other');
    await engine.evaluate('''globalThis.__hazuki_source={comic:{
      onHeaderAction:async()=>({
        headerStats:[{text:'11 likes',icon:'liked',action:'plugin',id:'like'}],
        headerBadges:[{text:'Paid',tone:'warning'}],
        reload:true,
      })}}''');
    const id = SourceScopedComicId(sourceKey: 'other', comicId: '7');
    cache.put(
      id.storageKey,
      const ComicDetailsData(
        id: '7',
        title: 'T',
        subTitle: '',
        cover: '',
        description: '',
        updateTime: '',
        likesCount: '',
        chapters: {},
        tags: {},
        recommend: [],
        isFavorite: false,
        subId: '',
        sourceKey: 'other',
      ),
      sourceKey: 'other',
    );
    final result = await capability.runComicHeaderAction(
      comicId: '7',
      actionId: 'like',
      sourceKey: 'other',
    );
    expect(result.reload, isTrue);
    expect(result.headerStats!.single.icon, 'liked');
    expect(result.headerStats!.single.actionId, 'like');
    final cached = cache.get(id.storageKey, sourceKey: 'other')!;
    expect(cached.headerStats.single.text, '11 likes');
    expect(cached.headerBadges.single.tone, ComicHeaderBadgeTone.warning);
  });

  test('missing callback and invalid results are reported', () async {
    final engine = engineFor('other');
    await engine.evaluate('globalThis.__hazuki_source={comic:{}}');
    await expectLater(
      capability.runComicHeaderAction(
        comicId: '7',
        actionId: 'x',
        sourceKey: 'other',
      ),
      throwsA(
        predicate((e) => '$e'.contains('comic_header_action_not_supported')),
      ),
    );
    await engine.evaluate(
      'globalThis.__hazuki_source={comic:{onHeaderAction:async()=>"bad"}}',
    );
    await expectLater(
      capability.runComicHeaderAction(
        comicId: '7',
        actionId: 'x',
        sourceKey: 'other',
      ),
      throwsFormatException,
    );
  });

  test(
    'retired like-position declarations do not create configurable buttons',
    () {
      expect(
        SourcePluginButton.parseList([
          {'id': 'comicLike', 'location': 'comicDetailHeader'},
          {'id': 'comicLike', 'location': 'advanced'},
        ]),
        isEmpty,
      );
    },
  );
}
