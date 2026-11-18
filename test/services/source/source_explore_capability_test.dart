import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/content/explore_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SourceUiService sourceUiService;

void main() {
  setUp(() {
    sourceUiService = SourceUiService();
  });
  tearDown(() {
    sourceUiService.detach();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceScriptEngine engine;
  late SourceExploreCapability explore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    host = SourceRuntimeHost(
      sourceUiService: sourceUiService,
      catalog: const [
        SourceCatalogEntry(key: 'one', name: 'One', fileName: 'one.js'),
      ],
      defaultSourceKey: 'one',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    addTearDown(host.dispose);
    engine = SourceScriptEngine(
      sourceUiService: sourceUiService,
      pluginId: 'one',
    );
    addTearDown(engine.close);
    final handle = host.activeHandle;
    handle.runtime.engine = engine;
    handle.runtime.sourceMeta = SourceMeta(
      name: 'One',
      key: 'one',
      version: '1',
      supportsAccount: false,
      settingsDefaults: {},
    );
    engine.operationGuard = handle.runOperation;
    explore = SourceExploreCapability(
      runtimeHost: host,
      translateSourceText: (text, {sourceKey = ''}) => text,
    );
  });

  Future<void> install(String secondLoad) => engine.execute('''
    globalThis.__hazuki_source = {explore: [
      {type: 'multiPageComicList', title: 'Healthy',
       load: async () => ({comics: [{id: 'healthy', title: 'Healthy comic'}], maxPage: 2})},
      {type: 'multiPageComicList', title: 'Second', load: $secondLoad}
    ]};
  ''');

  test('returns all successful sections in order', () async {
    await install(
      'async () => ({comics: [{id: "second", title: "Second comic"}]})',
    );

    final sections = await explore.load();

    expect(sections.map((section) => section.title), ['Healthy', 'Second']);
    expect(sections.first.comics.single.id, 'healthy');
    expect(sections.last.comics.single.id, 'second');
  });

  for (final asyncPrefix in ['', 'async ']) {
    test(
      'preserves successful sections after a ${asyncPrefix.isEmpty ? 'synchronous' : 'Promise'} failure',
      () async {
        await install('$asyncPrefix() => {throw new Error("section failed");}');

        final sections = await explore.load();

        expect(sections, hasLength(1));
        expect(sections.single.title, 'Healthy');
        expect(sections.single.comics.single.id, 'healthy');
        expect(sections.single.comics.single.sourceKey, 'one');
        expect(sections.single.maxPage, 2);
        expect(host.activeHandle.cache.getExploreSections(), sections);
      },
    );
  }

  test('cancellation stops loading without caching partial results', () async {
    final entered = Completer<void>();
    engine.setOperationMessageHandler((_, _) {
      if (!entered.isCompleted) entered.complete();
      return null;
    });
    await install('() => {sendMessage({entered:true});while(true){}}');
    final pending = explore.load(
      taskOrigin: SourceTaskOrigin(
        ownerId: 'discover-page',
        groupId: 'load',
        requestSequence: 1,
      ),
    );
    final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
    await entered.future.timeout(const Duration(seconds: 3));

    final receipt = await host.tasks.cancelOwner(
      'discover-page',
      SourceTaskStopReason.user,
    );
    await stopped.timeout(const Duration(seconds: 3));
    await receipt.whenSettled.timeout(const Duration(seconds: 3));

    expect(host.activeHandle.cache.getExploreSections(), isNull);
    expect(await engine.evaluate('42'), 42);
  });
}
