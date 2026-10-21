import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/state/search_results_controller.dart';
import 'package:hazuki/features/search/state/aggregate_search_results_controller.dart';
import 'package:hazuki/features/search/support/search_contracts.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/category/source_category_capability.dart';
import 'package:hazuki/services/source/comic/comic_details_capability.dart';
import 'package:hazuki/services/source/content/source_content_operations.dart';
import 'package:hazuki/services/source/explore_capability.dart';
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

class _SearchGateway extends ChangeNotifier implements SourceSearchGateway {
  _SearchGateway(this.host, this.content);
  final SourceRuntimeHost host;
  final SourceContentOperationService content;
  @override
  String get activeSourceKey => host.activeSourceKey;
  @override
  List<SourceCatalogEntry> get allowedSources => host.catalog;
  @override
  SourceRuntimeState get sourceRuntimeState => const SourceRuntimeState.idle();
  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = '',
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => content.searchComics(
    keyword: keyword,
    page: page,
    order: order,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingHttp implements HttpClientAdapter {
  final requests = <String, Completer<ResponseBody>>{};
  final aborted = <String>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final id = options.uri.pathSegments.last;
    final response = Completer<ResponseBody>();
    requests[id] = response;
    cancelFuture?.then((_) => aborted.add(id));
    return response.future;
  }

  @override
  void close({bool force = false}) {}
  void complete(String id) =>
      requests[id]!.complete(ResponseBody.fromString('{}', 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceContentOperationService content;
  late _SearchGateway gateway;
  late SourceScriptEngine engine;
  late _PendingHttp http;
  const messages = SearchMessages(timeout: 'timeout', failed: _failure);

  setUp(() async {
    host = SourceRuntimeHost(
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
    final operations = _Operations();
    when(
      () => operations.ensureSourceInitialized(any()),
    ).thenAnswer((_) async {});
    content = SourceContentOperationService(
      runtimeHost: host,
      runtimeOperations: operations,
      explore: _Explore(),
      category: _Category(),
      comicDetails: _Comic(),
    );
    addTearDown(content.dispose);
    gateway = _SearchGateway(host, content);
    addTearDown(gateway.dispose);
    engine = SourceScriptEngine(pluginId: 'one');
    addTearDown(engine.close);
    final handle = host.handleFor('one');
    handle.runtime.engine = engine;
    handle.runtime.sourceMeta = SourceMeta(
      name: 'One',
      key: 'one',
      version: '1',
      supportsAccount: false,
      settingsDefaults: {},
    );
    engine.operationGuard = handle.runOperation;
    http = _PendingHttp();
    handle.dio.httpClientAdapter = http;
    engine.setOperationMessageHandler(
      (message, context) => handle.httpGateway.sendJsHttpRequest(
        Map<String, dynamic>.from(message as Map),
        hostContext: context,
        execution: context.execution,
        runtimeId: context.runtimeId,
      ),
    );
  });

  Future<void> install(String load) =>
      engine.execute('globalThis.__hazuki_source={search:{load:$load}}');
  SearchResultsController controller() {
    final result = SearchResultsController(
      initialOrder: '',
      sourceService: gateway,
      taskControl: host.tasks,
    );
    return result;
  }

  Future<void> waitUntil(bool Function() condition) async {
    final clock = Stopwatch()..start();
    while (!condition() && clock.elapsed < const Duration(seconds: 2)) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(condition(), isTrue);
  }

  const httpSearch = '''keyword=>sendMessage({method:"http",http_method:"GET",
    url:"https://fixture.test/"+keyword}).then(()=>({comics:[{id:keyword,title:keyword}],maxPage:1}))''';

  test(
    'a replacement query aborts its exclusive HTTP and keeps the engine',
    () async {
      await install(httpSearch);
      final search = controller();
      addTearDown(search.dispose);
      final old = search.search(messages, keyword: 'old', page: 1);
      await waitUntil(() => http.requests.containsKey('old'));
      final next = search.search(messages, keyword: 'new', page: 1);
      await waitUntil(() => http.requests.containsKey('new'));
      await waitUntil(() => http.aborted.contains('old'));
      http.complete('new');
      await next;
      await old;
      expect(search.searchComics.single.id, 'new');
      expect(host.handleFor('one').runtime.engine, same(engine));
      http.complete('old');
    },
  );

  test(
    'disposing one search leaves another same-source HTTP consumer active',
    () async {
      await install(httpSearch);
      final first = controller();
      final second = controller();
      addTearDown(second.dispose);
      final a = first.search(messages, keyword: 'first', page: 1);
      final b = second.search(messages, keyword: 'second', page: 1);
      await waitUntil(() => http.requests.length == 2);
      first.dispose();
      await a;
      await waitUntil(() => http.aborted.contains('first'));
      expect(http.aborted, isNot(contains('second')));
      http.complete('second');
      await b;
      expect(second.searchComics.single.id, 'second');
      expect(await engine.evaluate('40+2'), 42);
      http.complete('first');
    },
  );

  test(
    'query cancellation removes a long worker Timer before its continuation',
    () async {
      final started = Completer<void>();
      engine.setMessageHandler((_) {
        started.complete();
        return null;
      });
      await install('''()=>{sendMessage({started:true});
      globalThis.continued=false;
      return sendMessage({method:"delay",time:60000}).then(()=>{
        continued=true;return {comics:[{id:"late"}]};});}''');
      final search = controller();
      final pending = search.search(messages, keyword: 'timer', page: 1);
      await started.future;
      final owner = host.tasks.activeTasks.single.ownerId;
      search.dispose();
      await pending;
      final receipt = await host.tasks.cancelOwner(
        owner,
        SourceTaskStopReason.ownerDisposed,
      );
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      expect(await engine.evaluate('continued'), isFalse);
      expect(host.tasks.activeTasks, isEmpty);
    },
  );

  test('switching from aggregate search cancels its old HTTP branch', () async {
    await install(httpSearch);
    final aggregate = AggregateSearchResultsController(
      sourceService: gateway,
      taskControl: host.tasks,
    );
    addTearDown(aggregate.dispose);
    final old = aggregate.search(messages, 'aggregate');
    await waitUntil(() => http.requests.containsKey('aggregate'));
    aggregate.stopPending(SourceTaskStopReason.superseded);
    await old;
    await waitUntil(() => http.aborted.contains('aggregate'));
    final next = controller();
    addTearDown(next.dispose);
    final pending = next.search(messages, keyword: 'single', page: 1);
    await waitUntil(() => http.requests.containsKey('single'));
    http.complete('single');
    await pending;
    expect(next.searchComics.single.id, 'single');
    http.complete('aggregate');
  });
}

String _failure(String error) => error;
