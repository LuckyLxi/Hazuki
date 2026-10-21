import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/logging/app_log_event.dart';
import 'package:hazuki/services/logging/app_log_store.dart';
import 'package:hazuki/services/source/category/source_category_capability.dart';
import 'package:hazuki/services/source/comic/comic_details_capability.dart';
import 'package:hazuki/services/source/content/source_content_operations.dart';
import 'package:hazuki/services/source/explore_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_operations.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _Operations extends Mock implements SourceRuntimeOperations {}

class _Explore extends Mock implements SourceExploreCapability {}

class _Category extends Mock implements SourceCategoryCapability {}

class _Comic extends Mock implements SourceComicDetailsCapability {}

class _Engine extends Mock implements SourceScriptEngine {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceContentOperationService content;
  late _Operations operations;
  late AppLogStore logs;

  Future<SourceScriptEngine> install(
    String implementation, {
    String version = '1.0',
  }) async {
    final engine = SourceScriptEngine();
    addTearDown(engine.close);
    await engine.evaluate(
      'globalThis.__hazuki_source = {search: {load: $implementation}}',
    );
    final handle = host.handleFor('one');
    handle.runtime
      ..engine = engine
      ..sourceMeta = SourceMeta(
        name: 'One',
        key: 'one',
        version: version,
        supportsAccount: false,
        settingsDefaults: {},
      );
    return engine;
  }

  List<AppLogEvent> events(String name) =>
      logs.events.where((event) => event.event == name).toList();
  Map data(AppLogEvent event) => event.data as Map;

  setUp(() async {
    logs = AppLogStore();
    addTearDown(logs.dispose);
    await logs.setCaptureEnabled(true);
    operations = _Operations();
    when(
      () => operations.ensureSourceInitialized(any()),
    ).thenAnswer((_) async {});
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'one',
          name: 'One',
          fileName: 'one.js',
          pluginVersion: '1.0',
        ),
      ],
      defaultSourceKey: 'one',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
      logStore: logs,
    );
    addTearDown(host.dispose);
    content = SourceContentOperationService(
      runtimeHost: host,
      runtimeOperations: operations,
      explore: _Explore(),
      category: _Category(),
      comicDetails: _Comic(),
    );
    addTearDown(content.dispose);
  });

  for (final asynchronous in [false, true]) {
    test(
      'traces ${asynchronous ? 'Promise' : 'synchronous'} search results and parsing',
      () async {
        final engine = await install(
          '${asynchronous ? 'async ' : ''}(keyword, orders, page) => ({comics: [{id: "comic", title: keyword}], maxPage: "3"})',
        );
        final origin = SourceTaskOrigin.standalone();
        final result = await content.searchComics(
          keyword: 'private-query',
          page: 1,
          taskOrigin: origin,
        );
        expect(result.comics.single.title, 'private-query');
        expect(result.maxPage, 3);
        expect(content.activeSearchTasks, isEmpty);
        final succeeded = data(events('source_task_succeeded').single);
        expect(succeeded['runtimeId'], engine.runtimeId);
        expect(succeeded['ownerId'], origin.ownerId);
        expect(succeeded['groupId'], origin.groupId);
        expect(succeeded['pluginVersion'], '1.0');
        expect(
          logs.events.map((e) => e.data).toString(),
          isNot(contains('private-query')),
        );
        expect(events('source_task_result_discarded'), isEmpty);
      },
    );

    test(
      'traces ${asynchronous ? 'Promise' : 'synchronous'} script failures without changing the error',
      () async {
        await install(
          '${asynchronous ? 'async ' : ''}(keyword) => {throw new Error("search failed: " + keyword + " token=secret");}',
        );
        await expectLater(
          content.searchComics(keyword: 'private-query', page: 1),
          throwsA(
            predicate((error) => error.toString().contains('private-query')),
          ),
        );
        expect(content.activeSearchTasks, isEmpty);
        final failed = data(events('source_task_failed').single);
        expect(failed['scriptStack'], contains('source_search.js'));
        expect(failed['runtimeId'], isNotNull);
        expect(failed['error'], contains('[hidden]'));
        expect(
          logs.events.map((e) => e.data).toString(),
          isNot(contains('private-query')),
        );
        expect(
          logs.events.map((e) => e.data).toString(),
          isNot(contains('token=secret')),
        );
      },
    );
  }

  test('initialization failures are tasks without a bound engine', () async {
    when(
      () => operations.ensureSourceInitialized('one'),
    ).thenThrow(StateError('init failed'));
    await expectLater(
      content.searchComics(keyword: 'query', page: 1),
      throwsStateError,
    );
    final failed = data(events('source_task_failed').single);
    expect(failed['runtimeId'], isNull);
    expect(failed['pluginVersion'], '1.0');
    expect(failed['error'], contains('init failed'));
    expect(content.activeSearchTasks, isEmpty);
  });

  test(
    'binds the engine actually available after initialization and changes identity on rebuild',
    () async {
      final old = await install('() => ({comics: []})');
      final ready = Completer<void>();
      when(
        () => operations.ensureSourceInitialized('one'),
      ).thenAnswer((_) => ready.future);
      final pending = content.searchComics(keyword: 'query', page: 1);
      expect(content.activeSearchTasks.single.runtimeId, isNull);
      final replacement = await install('() => ({comics: []})', version: '2.0');
      ready.complete();
      await pending;
      var completed = data(events('source_task_succeeded').single);
      expect(completed['runtimeId'], replacement.runtimeId);
      expect(completed['runtimeId'], isNot(old.runtimeId));
      expect(completed['pluginVersion'], '2.0');
      final next = await install('() => ({comics: []})', version: '3.0');
      await content.searchComics(keyword: 'query', page: 1);
      completed = data(events('source_task_succeeded').last);
      expect(completed['runtimeId'], next.runtimeId);
      expect(completed['pluginVersion'], '3.0');
      expect(
        completed['taskId'],
        isNot(data(events('source_task_succeeded').first)['taskId']),
      );
    },
  );

  test(
    'concurrent results have independent task logs and stale results remain successful executions',
    () async {
      final responses = [
        Completer<Map<String, dynamic>>(),
        Completer<Map<String, dynamic>>(),
      ];
      final started = Completer<void>();
      final engine = await install(
        '(keyword) => sendMessage({index: Number(keyword)})',
      );
      var calls = 0;
      engine.setMessageHandler((message) {
        if (++calls == 2) started.complete();
        return responses[message['index'] as int].future;
      });
      var disposition = SourceTaskResultDisposition.current;
      final first = content.searchComics(
        keyword: '0',
        page: 1,
        taskOrigin: SourceTaskOrigin(
          ownerId: 'owner',
          groupId: 'old',
          requestSequence: 1,
          resultDisposition: () => disposition,
        ),
      );
      final second = content.searchComics(
        keyword: '1',
        page: 1,
        taskOrigin: const SourceTaskOrigin(
          ownerId: 'owner',
          groupId: 'new',
          requestSequence: 2,
        ),
      );
      await started.future;
      expect(content.activeSearchTasks, hasLength(2));
      disposition = SourceTaskResultDisposition.superseded;
      responses[1].complete({
        'comics': [
          {'id': 'new', 'title': 'New'},
        ],
      });
      expect((await second).comics.single.id, 'new');
      expect(content.activeSearchTasks, hasLength(1));
      responses[0].complete({
        'comics': [
          {'id': 'old', 'title': 'Old'},
        ],
      });
      expect((await first).comics.single.id, 'old');
      expect(content.activeSearchTasks, isEmpty);
      final completed = events('source_task_succeeded').map(data).toList();
      expect(completed.map((task) => task['groupId']), ['new', 'old']);
      expect(completed.map((task) => task['taskId']).toSet(), hasLength(2));
      final discarded = data(events('source_task_result_discarded').single);
      expect(discarded['taskId'], completed.last['taskId']);
      expect(discarded['state'], 'succeeded');
      expect(discarded['resultDisposition'], 'superseded');
    },
  );

  test(
    'holds the handle until plugin waiting and result parsing finish',
    () async {
      final response = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      final engine = await install('() => sendMessage({})');
      engine.setMessageHandler((_) {
        started.complete();
        return response.future;
      });
      final SourceRuntimeHandle handle = host.handleFor('one');
      final pending = content.searchComics(keyword: 'query', page: 1);
      await started.future;
      host.remove('one');
      expect(handle.isDisposed, isFalse);
      response.complete({
        'comics': [
          {'id': 'comic', 'title': 'Comic'},
        ],
      });
      expect((await pending).comics.single.id, 'comic');
      expect(handle.isDisposed, isTrue);
      expect(content.activeSearchTasks, isEmpty);
      expect(events('source_task_succeeded'), hasLength(1));
    },
  );

  test(
    'a caller timeout leaves execution active until its result arrives',
    () async {
      final response = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      final engine = await install('() => sendMessage({})');
      engine.setMessageHandler((_) {
        started.complete();
        return response.future;
      });
      var timedOut = false;
      final pending = content.searchComics(
        keyword: 'query',
        page: 1,
        taskOrigin: SourceTaskOrigin(
          ownerId: 'owner',
          groupId: 'group',
          requestSequence: 1,
          resultDisposition: () => timedOut
              ? SourceTaskResultDisposition.timedOut
              : SourceTaskResultDisposition.current,
        ),
      );
      await started.future;
      await expectLater(
        pending.timeout(
          Duration.zero,
          onTimeout: () {
            timedOut = true;
            throw TimeoutException('caller timeout');
          },
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(content.activeSearchTasks.single.state, SourceTaskState.running);
      expect(events('source_task_succeeded'), isEmpty);
      expect(events('source_task_failed'), isEmpty);
      response.complete({'comics': []});
      await pending;
      expect(content.activeSearchTasks, isEmpty);
      expect(events('source_task_succeeded'), hasLength(1));
      expect(
        data(
          events('source_task_result_discarded').single,
        )['resultDisposition'],
        'timedOut',
      );
    },
  );

  test(
    'result parsing errors release both the task and the operation lease',
    () async {
      final engine = _Engine();
      when(() => engine.close()).thenAnswer((_) async {});
      when(() => engine.runtimeId).thenReturn('malformed-engine');
      when(() => engine.hasExecutionWork(any())).thenReturn(false);
      when(
        () => engine.evaluate(
          any(),
          name: any(named: 'name'),
          execution: any(named: 'execution'),
        ),
      ).thenAnswer((_) async => {1: 'invalid key'});
      when(
        () => engine.evaluate(
          '!!this.__hazuki_source.search',
          execution: any(named: 'execution'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => engine.evaluate(
          '!!this.__hazuki_source.search?.load',
          execution: any(named: 'execution'),
        ),
      ).thenAnswer((_) async => true);
      final handle = host.handleFor('one');
      handle.runtime.engine = engine;
      await expectLater(
        content.searchComics(keyword: 'query', page: 1),
        throwsA(isA<TypeError>()),
      );
      expect(content.activeSearchTasks, isEmpty);
      expect(
        data(events('source_task_failed').single)['runtimeId'],
        'malformed-engine',
      );
      handle.requestDispose();
      expect(handle.isDisposed, isTrue);
    },
  );

  test('capability check failures are inside the task boundary', () async {
    await install('() => ({comics: [{id: "ok"}], maxPage: 1})');
    await host
        .handleFor('one')
        .runtime
        .engine!
        .evaluate(
          'Object.defineProperty(__hazuki_source, "search", {get() {throw new Error("capability failed");}})',
        );
    await expectLater(
      content.searchComics(keyword: 'query', page: 1),
      throwsA(anything),
    );
    expect(events('source_task_failed'), hasLength(1));
    expect(content.activeSearchTasks, isEmpty);
  });
}
