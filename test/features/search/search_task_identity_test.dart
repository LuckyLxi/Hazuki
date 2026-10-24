import '../../support/fake_source_task_control.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/state/aggregate_search_results_controller.dart';
import 'package:hazuki/features/search/state/search_results_controller.dart';
import 'package:hazuki/features/search/support/search_contracts.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class _Request {
  _Request(this.origin, this.sourceKey, this.page);
  final SourceTaskOrigin origin;
  final String sourceKey;
  final int page;
}

class _Source extends ChangeNotifier implements SourceSearchGateway {
  final requests = <_Request>[];
  Future<SearchComicsResult> Function(_Request)? respond;

  @override
  String get activeSourceKey => 'one';
  @override
  List<SourceCatalogEntry> allowedSources = const [
    SourceCatalogEntry(
      key: 'one',
      name: 'One',
      fileName: 'one.js',
      pluginVersion: '1.0',
      presentation: {
        'searchOrders': {'a': 'A', 'b': 'B'},
      },
    ),
    SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
  ];
  @override
  SourceRuntimeState get runtimeState => const SourceRuntimeState.idle();

  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = '',
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) {
    final request = _Request(taskOrigin!, sourceKey, page);
    requests.add(request);
    return respond?.call(request) ?? Future.value(_result('$sourceKey-$page'));
  }

  void replacePlugin() {
    allowedSources = const [
      SourceCatalogEntry(
        key: 'one',
        name: 'One',
        fileName: 'one.js',
        pluginVersion: '2.0',
      ),
    ];
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SearchComicsResult _result(String id) => SearchComicsResult(
  comics: [ExploreComic(id: id, title: id, subTitle: '', cover: '')],
  maxPage: 3,
);

const _messages = SearchMessages(timeout: 'timeout', failed: _failure);
String _failure(String message) => message;

void main() {
  late _Source source;
  SearchResultsController single() {
    final controller = SearchResultsController(
      taskControl: FakeSourceTaskControl(),
      initialOrder: '',
      sourceService: source,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  AggregateSearchResultsController aggregate() {
    final controller = AggregateSearchResultsController(
      taskControl: FakeSourceTaskControl(),
      sourceService: source,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  setUp(() {
    source = _Source();
    addTearDown(source.dispose);
  });

  test(
    'single search groups retries and pagination while owners and new searches remain distinct',
    () async {
      final first = single();
      var count = 0;
      source.respond = (_) async => ++count == 1
          ? const SearchComicsResult(comics: [], maxPage: null)
          : _result('comic-$count');
      await first.search(_messages, keyword: 'first', page: 1);
      await first.loadMoreSearch(_messages);
      final origins = source.requests.map((request) => request.origin).toList();
      expect(origins, hasLength(3));
      expect(origins.map((origin) => origin.groupId).toSet(), hasLength(1));
      expect(origins[0].requestSequence, origins[1].requestSequence);
      expect(
        origins[2].requestSequence,
        greaterThan(origins[1].requestSequence),
      );
      await first.search(_messages, keyword: 'second', page: 1);
      expect(source.requests.last.origin.groupId, isNot(origins.first.groupId));
      expect(source.requests.last.origin.ownerId, origins.first.ownerId);
      final second = single();
      await second.search(_messages, keyword: 'second', page: 1);
      expect(source.requests.last.origin.ownerId, isNot(origins.first.ownerId));
    },
  );

  test(
    'late single results retain origin and cannot overwrite a newer search',
    () async {
      final controller = single();
      final oldResponse = Completer<SearchComicsResult>();
      source.respond = (_) => source.requests.length == 1
          ? oldResponse.future
          : Future.value(_result('new'));
      final oldSearch = controller.search(_messages, keyword: 'old', page: 1);
      final oldOrigin = source.requests.single.origin;
      await controller.search(_messages, keyword: 'new', page: 1);
      expect(
        oldOrigin.resultDisposition!(),
        SourceTaskResultDisposition.superseded,
      );
      oldResponse.complete(_result('old'));
      await oldSearch;
      expect(controller.searchComics.single.id, 'new');
      expect(
        source.requests.last.origin.resultDisposition!(),
        SourceTaskResultDisposition.current,
      );
    },
  );

  for (final dispose in [false, true]) {
    test(
      'single ${dispose ? 'disposal' : 'plugin replacement'} invalidates pending results',
      () async {
        final controller = SearchResultsController(
          taskControl: FakeSourceTaskControl(),
          initialOrder: '',
          sourceService: source,
        );
        final response = Completer<SearchComicsResult>();
        source.respond = (_) => response.future;
        final pending = controller.search(_messages, keyword: 'query', page: 1);
        final origin = source.requests.single.origin;
        if (dispose) {
          controller.dispose();
        } else {
          addTearDown(controller.dispose);
          source.replacePlugin();
        }
        expect(
          origin.resultDisposition!(),
          dispose
              ? SourceTaskResultDisposition.disposed
              : SourceTaskResultDisposition.superseded,
        );
        expect(
          origin.cancellation!.reason,
          dispose
              ? SourceTaskStopReason.ownerDisposed
              : SourceTaskStopReason.pluginUpdated,
        );
        response.complete(_result('obsolete'));
        await pending;
        expect(controller.searchComics, isEmpty);
      },
    );
  }

  test(
    'aggregate sources share a group and preserve successful sections through retry and pagination',
    () async {
      final controller = aggregate();
      var failed = false;
      source.respond = (request) async {
        if (request.sourceKey == 'two' && !failed) {
          failed = true;
          throw StateError('unavailable');
        }
        return _result('${request.sourceKey}-${request.page}');
      };
      await controller.search(_messages, 'query');
      expect(controller.sections.first.comics.single.id, 'one-1');
      expect(controller.sections.last.errorMessage, contains('unavailable'));
      final firstGroup = source.requests.first.origin.groupId;
      expect(source.requests.map((request) => request.origin.groupId).toSet(), {
        firstGroup,
      });
      await controller.retry(_messages, controller.sections.last);
      await controller.loadMore(_messages, controller.sections.first);
      expect(
        source.requests.every(
          (request) => request.origin.groupId == firstGroup,
        ),
        isTrue,
      );
      expect(controller.sections.first.comics.map((comic) => comic.id), [
        'one-1',
        'one-2',
      ]);
      await controller.changeOrder(_messages, controller.sections.first, 'b');
      expect(source.requests.last.origin.groupId, isNot(firstGroup));
      expect(controller.sections.last.taskGroupId, firstGroup);
      await controller.search(_messages, 'next');
      final newOrigins = source.requests
          .skip(source.requests.length - 2)
          .map((r) => r.origin);
      expect(newOrigins.map((origin) => origin.groupId).toSet(), hasLength(1));
      expect(newOrigins.first.groupId, isNot(firstGroup));
    },
  );

  for (final dispose in [false, true]) {
    test(
      'aggregate ${dispose ? 'disposal' : 'plugin replacement'} rejects late sections',
      () async {
        final controller = AggregateSearchResultsController(
          taskControl: FakeSourceTaskControl(),
          sourceService: source,
        );
        final response = Completer<SearchComicsResult>();
        source.respond = (_) => response.future;
        final pending = controller.search(_messages, 'query');
        final origins = source.requests
            .map((request) => request.origin)
            .toList();
        if (dispose) {
          controller.dispose();
        } else {
          addTearDown(controller.dispose);
          source.replacePlugin();
        }
        expect(
          origins.every(
            (origin) =>
                origin.resultDisposition!() ==
                (dispose
                    ? SourceTaskResultDisposition.disposed
                    : SourceTaskResultDisposition.superseded),
          ),
          isTrue,
        );
        response.complete(_result('obsolete'));
        await pending;
        expect(
          controller.sections.every((section) => section.comics.isEmpty),
          isTrue,
        );
      },
    );
  }

  testWidgets(
    'single caller timeout does not mark later execution as cancelled',
    (tester) async {
      final controller = single();
      final response = Completer<SearchComicsResult>();
      source.respond = (_) => response.future;
      final pending = controller.search(_messages, keyword: 'query', page: 2);
      final origin = source.requests.single.origin;
      await tester.pump(searchLoadTimeout);
      await pending;
      expect(origin.resultDisposition!(), SourceTaskResultDisposition.timedOut);
      expect(controller.searchErrorMessage, contains('timeout'));
      expect(
        origin.cancellation!.reason,
        SourceTaskStopReason.deadlineExceeded,
      );
      response.complete(_result('late'));
      await tester.pump();
      expect(controller.searchComics, isEmpty);
    },
  );

  testWidgets('aggregate caller timeout leaves late results obsolete', (
    tester,
  ) async {
    final controller = aggregate();
    final response = Completer<SearchComicsResult>();
    source.respond = (_) => response.future;
    final pending = controller.search(_messages, 'query');
    await tester.pump(searchLoadTimeout);
    await pending;
    for (final section in controller.sections) {
      expect(section.errorMessage, contains('timeout'));
      expect(section.loading, isFalse);
      expect(section.loadingMore, isFalse);
    }
    expect(
      source.requests.every(
        (request) =>
            request.origin.resultDisposition!() ==
            SourceTaskResultDisposition.timedOut,
      ),
      isTrue,
    );
    response.complete(_result('late'));
    await tester.pump();
    expect(
      controller.sections.every((section) => section.comics.isEmpty),
      isTrue,
    );
  });

  testWidgets('aggregate timeout preserves other sources and permits retry', (
    tester,
  ) async {
    final controller = aggregate();
    final response = Completer<SearchComicsResult>();
    source.respond = (request) => request.sourceKey == 'one'
        ? Future.value(_result('successful'))
        : response.future;
    final pending = controller.search(_messages, 'query');
    await tester.pump(searchLoadTimeout);
    await pending;

    final successful = controller.sections.first;
    final timedOut = controller.sections.last;
    expect(successful.comics.single.id, 'successful');
    expect(successful.errorMessage, isNull);
    expect(timedOut.errorMessage, contains('timeout'));
    expect(timedOut.loading, isFalse);
    expect(timedOut.loadingMore, isFalse);
    final timedOutOrigin = source.requests.last.origin;
    expect(
      timedOutOrigin.resultDisposition!(),
      SourceTaskResultDisposition.timedOut,
    );

    source.respond = (_) => Future.value(_result('retried'));
    await controller.retry(_messages, timedOut);
    response.complete(_result('late'));
    await tester.pump();
    expect(successful.comics.single.id, 'successful');
    expect(timedOut.comics.single.id, 'retried');
    expect(timedOut.errorMessage, isNull);
    expect(timedOut.loading, isFalse);
    expect(timedOut.loadingMore, isFalse);
    expect(
      timedOutOrigin.resultDisposition!(),
      SourceTaskResultDisposition.timedOut,
    );
    expect(
      source.requests.last.origin.resultDisposition!(),
      SourceTaskResultDisposition.current,
    );
  });

  testWidgets('aggregate pagination timeout retains loaded comics', (
    tester,
  ) async {
    final controller = aggregate();
    await controller.search(_messages, 'query');
    final section = controller.sections.first;
    final response = Completer<SearchComicsResult>();
    source.respond = (_) => response.future;
    final pending = controller.loadMore(_messages, section);
    expect(section.loadingMore, isTrue);
    await tester.pump(searchLoadTimeout);
    await pending;

    expect(section.comics.single.id, 'one-1');
    expect(section.page, 1);
    expect(section.errorMessage, contains('timeout'));
    expect(section.loading, isFalse);
    expect(section.loadingMore, isFalse);
    response.complete(_result('late-page'));
    await tester.pump();
    expect(section.comics.single.id, 'one-1');
    expect(section.page, 1);
  });

  testWidgets('obsolete aggregate errors cannot overwrite a newer search', (
    tester,
  ) async {
    final controller = aggregate();
    final response = Completer<SearchComicsResult>();
    source.respond = (_) => response.future;
    final oldSearch = controller.search(_messages, 'old');
    final oldOrigins = source.requests
        .map((request) => request.origin)
        .toList();
    source.respond = (request) =>
        Future.value(_result('new-${request.sourceKey}'));
    await controller.search(_messages, 'new');
    await oldSearch;
    response.completeError(StateError('late failure'));
    await tester.pump(searchLoadTimeout);

    for (final section in controller.sections) {
      expect(section.comics.single.id, 'new-${section.source.key}');
      expect(section.errorMessage, isNull);
      expect(section.loading, isFalse);
      expect(section.loadingMore, isFalse);
    }
    expect(
      oldOrigins.every(
        (origin) =>
            origin.resultDisposition!() ==
            SourceTaskResultDisposition.superseded,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  for (final throwsError in [false, true]) {
    testWidgets(
      'disposal cancels the retry gap after ${throwsError ? 'failure' : 'empty results'}',
      (tester) async {
        final control = FakeSourceTaskControl();
        final controller = SearchResultsController(
          initialOrder: '',
          sourceService: source,
          taskControl: control,
        );
        source.respond = (_) => throwsError
            ? Future.error(StateError('unavailable'))
            : Future.value(const SearchComicsResult(comics: [], maxPage: null));
        final pending = controller.search(_messages, keyword: 'query', page: 1);
        await tester.pump();
        expect(source.requests, hasLength(1));
        controller.dispose();
        await pending;
        await tester.pump(const Duration(seconds: 1));
        expect(source.requests, hasLength(1));
        expect(
          source.requests.single.origin.cancellation!.reason,
          SourceTaskStopReason.ownerDisposed,
        );
        expect(
          control.requests.last.reason,
          SourceTaskStopReason.ownerDisposed,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('aggregate retry cancels only its own source branch', () async {
    final control = FakeSourceTaskControl();
    final controller = AggregateSearchResultsController(
      sourceService: source,
      taskControl: control,
    );
    addTearDown(controller.dispose);
    await controller.search(_messages, 'query');
    final first = source.requests[0].origin;
    final other = source.requests[1].origin;
    control.requests.clear();
    await controller.retry(_messages, controller.sections.first);
    expect(control.requests.single.kind, 'group');
    expect(control.requests.single.pluginId, 'one');
    expect(first.cancellation!.reason, SourceTaskStopReason.superseded);
    expect(other.cancellation!.reason, isNull);
    expect(controller.sections.last.comics.single.id, 'two-1');
  });
}
