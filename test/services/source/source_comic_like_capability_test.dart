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
          presentation: {'showComicLike': true},
        ),
      ],
      defaultSourceKey: 'arbitrary',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    capability = SourceComicDetailsCapability(
      runtimeHost: host,
      cache: SourceComicDetailsCache(runtimeHost: host),
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
    'detects callable likeComic after initialization without a display flag or source ID',
    () {
      expect(capability.supportComicLikeForSource('arbitrary'), isFalse);
      final engine = engineFor('arbitrary');
      engine.evaluate(
        'globalThis.__hazuki_source = {comic:{likeComic:async()=>{}}}',
      );
      expect(capability.supportComicLikeForSource('arbitrary'), isTrue);
      expect(capability.supportComicLike, isTrue);
      expect(capability.supportComicLikeForSource('other'), isFalse);
      expect(capability.supportComicLikeForSource('missing'), isFalse);
      engine.evaluate('delete this.__hazuki_source.comic.likeComic');
      expect(capability.supportComicLikeForSource('arbitrary'), isFalse);
    },
  );

  test('truthy values and legacy display flags cannot enable a like button', () {
    final engine = engineFor('other');
    for (final value in ['true', '"enabled"', '{}', '1', 'null']) {
      engine.evaluate(
        'globalThis.__hazuki_source = {comic:{likeComic:$value},presentation:{showComicLike:true}}',
      );
      expect(capability.supportComicLikeForSource('other'), isFalse);
    }
  });

  test(
    'like and unlike call the target plugin even when another source is active',
    () async {
      final active = engineFor('arbitrary');
      active.evaluate(
        'globalThis.__hazuki_source={comic:{likeComic:()=>{throw "wrong_source"}}}',
      );
      final target = engineFor('other');
      target.evaluate(
        'globalThis.likeCalls=[]; globalThis.__hazuki_source={comic:{likeComic:async(id,liked)=>{likeCalls.push([id,liked]);}}}',
      );
      await capability.toggleComicLike(
        comicId: 'comic"id',
        isLike: true,
        sourceKey: 'other',
      );
      await capability.toggleComicLike(
        comicId: 'comic"id',
        isLike: false,
        sourceKey: 'other',
      );
      expect(
        target.evaluate('JSON.stringify(likeCalls)'),
        '[["comic\\"id",true],["comic\\"id",false]]',
      );
      expect(host.activeSourceKey, 'arbitrary');
    },
  );

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
