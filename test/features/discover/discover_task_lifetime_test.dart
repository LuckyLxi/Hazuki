import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/state/discover_page_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

import '../../support/fake_source_task_control.dart';

class _Source extends ChangeNotifier implements SourceDiscoverGateway {
  final origins = <SourceTaskOrigin>[];
  final responses = <Completer<List<ExploreSection>>>[];
  String revision = '1';
  @override
  String get activeSourceKey => 'one';
  @override
  String get sourceRevision => revision;
  @override
  bool get requiresLogin => false;
  @override
  bool get isLogged => false;
  @override
  SourceRuntimeState get runtimeState => const SourceRuntimeState.idle();
  @override
  void logRuntimeRetryRequested(String source) {}
  @override
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
    SourceTaskOrigin? taskOrigin,
  }) {
    origins.add(taskOrigin!);
    final response = Completer<List<ExploreSection>>();
    responses.add(response);
    return response.future;
  }

  @override
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = '',
    List<String>? orders,
    SourceTaskOrigin? taskOrigin,
  }) async {
    origins.add(taskOrigin!);
    return const CategoryComicsResult(comics: [], maxPage: 1);
  }

  @override
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
    SourceTaskOrigin? taskOrigin,
  }) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Source source;
  late FakeSourceTaskControl control;
  late DiscoverPageController controller;
  Future<void> load() => controller.loadInitial(
    timeoutMessage: 'timeout',
    loadFailedMessage: (error) => error,
  );
  ExploreSection section(String title) => ExploreSection(
    title: title,
    comics: const [],
    viewMoreUrl: 'category:genre',
  );
  setUp(() {
    source = _Source();
    control = FakeSourceTaskControl();
    controller = DiscoverPageController(
      sourceService: source,
      taskControl: control,
    );
    addTearDown(controller.dispose);
    addTearDown(source.dispose);
  });

  test(
    'replacement signals the old group and ignores its late result',
    () async {
      final old = load();
      final oldOrigin = source.origins.single;
      final current = load();
      expect(oldOrigin.cancellation!.reason, SourceTaskStopReason.superseded);
      source.responses[1].complete([section('new')]);
      await current;
      source.responses[0].complete([section('old')]);
      await old;
      expect(controller.sections.single.title, 'new');
      expect(source.origins[1].groupId, isNot(oldOrigin.groupId));
      expect(control.requests.where((r) => r.kind == 'group'), isNotEmpty);
    },
  );

  test(
    'pagination keeps the query group and allocates a new call sequence',
    () async {
      final first = load();
      source.responses.single.complete([section('one')]);
      await first;
      await controller.loadMoreSection(0);
      expect(source.origins, hasLength(2));
      expect(source.origins[1].groupId, source.origins[0].groupId);
      expect(
        source.origins[1].requestSequence,
        greaterThan(source.origins[0].requestSequence),
      );
    },
  );

  test(
    'version invalidation stops pending work without submitting its result',
    () async {
      final pending = load();
      final origin = source.origins.single;
      source.revision = '2';
      source.notifyListeners();
      expect(origin.cancellation!.reason, SourceTaskStopReason.pluginUpdated);
      source.responses.single.complete([section('obsolete')]);
      await pending;
      expect(controller.sections, isEmpty);
      expect(
        control.requests.any(
          (r) => r.reason == SourceTaskStopReason.pluginUpdated,
        ),
        isTrue,
      );
    },
  );
  test('disposal releases only the controller owner', () async {
    final anotherControl = FakeSourceTaskControl();
    final another = DiscoverPageController(
      sourceService: source,
      taskControl: anotherControl,
    );
    final pending = another.loadInitial(
      timeoutMessage: 'timeout',
      loadFailedMessage: (error) => error,
    );
    final origin = source.origins.single;
    another.dispose();
    await pending;
    source.responses.single.complete([]);
    expect(
      anotherControl.requests.where((r) => r.kind == 'owner').single.id,
      origin.ownerId,
    );
    expect(control.requests, isEmpty);
  });
}
