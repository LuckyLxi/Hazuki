import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/account/source_account_operations.dart';
import 'package:hazuki/services/source/content/source_content_operations.dart';
import 'package:hazuki/services/source/favorites/source_favorites_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_runtime_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_view.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(const {}));
  tearDown(() async => sl.reset());

  test('service locator registers focused source gateways', () async {
    await ensureTestServiceLocator();

    expect(sl<SourceSearchGateway>(), isA<HazukiSourceSearchAdapter>());
    expect(sl<SourceDiscoverGateway>(), isA<HazukiSourceDiscoverAdapter>());
    expect(sl<SourceFavoriteGateway>(), isA<HazukiSourceFavoriteAdapter>());
    expect(sl<SourceReaderGateway>(), isA<HazukiSourceReaderAdapter>());
    expect(sl<SourceSettingsGateway>(), isA<HazukiSourceSettingsAdapter>());
    expect(sl<SourceAccountGateway>(), isA<HazukiSourceAccountAdapter>());
    expect(sl<SourceDebugGateway>(), isA<HazukiSourceDebugAdapter>());
    expect(sl<SourceImageGateway>(), isA<HazukiSourceImageAdapter>());
    expect(sl<SourceSyncGateway>(), isA<HazukiSourceSyncAdapter>());
    expect(sl<SourceRuntimeGateway>(), isA<HazukiSourceRuntimeAdapter>());
    expect(sl<SourceCommentsGateway>(), isA<HazukiSourceCommentsAdapter>());
  });

  test(
    'gateway set shares runtime adapters and forwards view notifications',
    () {
      final assembly = SourceRuntimeAssembly();
      addTearDown(assembly.dispose);
      final gateways = assembly.gateways;
      var notifications = 0;

      gateways.search.addListener(() => notifications++);
      assembly.testing.notifyRuntimeView();

      expect(notifications, 1);
      expect(identical(gateways.runtimeGateway, gateways.selection), isTrue);
      expect(
        identical(gateways.runtimeGateway, gateways.switchGateway),
        isTrue,
      );
    },
  );

  test(
    'sync gateway reads the active source through its runtime view',
    () async {
      final assembly = SourceRuntimeAssembly();
      addTearDown(assembly.dispose);

      expect(assembly.gateways.sync.activeSourceKey, 'jm');
      await assembly.runtimeRegistry.activateSource('copy_manga');

      expect(assembly.gateways.sync.activeSourceKey, 'copy_manga');
    },
  );

  test(
    'search adapter forwards scope and listener through minimal fakes',
    () async {
      final runtime = _FakeRuntimeView(activeSourceKey: 'picacg');
      final content = _FakeContentOperations();
      final adapter = HazukiSourceSearchAdapter(
        runtime: runtime,
        content: content,
      );
      var notifications = 0;
      adapter.addListener(() => notifications++);

      runtime.emit();
      await adapter.searchComics(
        keyword: 'hazuki',
        page: 2,
        order: 'vd',
        sourceKey: 'picacg',
      );

      expect(notifications, 1);
      expect(content.searchCalls, [('hazuki', 2, 'vd', 'picacg')]);
    },
  );

  test(
    'favorite and sync adapters forward streams and runtime operations',
    () async {
      final runtime = _FakeRuntimeView();
      final runtimeOperations = _FakeRuntimeOperations();
      final favorites = _FakeFavoritesOperations();
      final favorite = HazukiSourceFavoriteAdapter(
        runtime: runtime,
        account: _FakeAccountOperations(),
        favorites: favorites,
        runtimeOperations: runtimeOperations,
      );
      final received = <void>[];
      final subscription = favorite.cloudFavoritesChangedStream.listen(
        received.add,
      );
      final sync = HazukiSourceSyncAdapter(
        runtime: runtime,
        runtimeOperations: runtimeOperations,
      );

      favorites.emitChanged();
      await Future<void>.delayed(Duration.zero);
      await sync.writeLocalActiveSource('edited source');
      await sync.reloadFromLocalSourceFiles();

      expect(received, hasLength(1));
      expect(runtimeOperations.writtenSource, 'edited source');
      expect(runtimeOperations.reloadCalls, 1);
      await subscription.cancel();
      await favorites.dispose();
    },
  );

  test(
    'bootstrap adapter forwards initialization callback and source key',
    () async {
      final operations = _FakeRuntimeOperations();
      final adapter = HazukiSourceBootstrapAdapter(operations);
      void onProgress(int _, int _) {}

      await adapter.init(onProgress: onProgress);
      await adapter.ensureInitialized(sourceKey: 'copy_manga');

      expect(operations.initProgress, same(onProgress));
      expect(operations.ensureSourceKeys, ['copy_manga']);
    },
  );
}

class _FakeRuntimeView extends ChangeNotifier implements SourceRuntimeView {
  _FakeRuntimeView({this.activeSourceKey = 'jm'});

  @override
  String activeSourceKey;

  void emit() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeContentOperations implements SourceContentOperations {
  final searchCalls = <(String, int, String, String)>[];

  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  }) async {
    searchCalls.add((keyword, page, order, sourceKey));
    return const SearchComicsResult(comics: [], maxPage: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFavoritesOperations implements SourceFavoritesOperations {
  final _changes = StreamController<void>.broadcast();

  void emitChanged() => _changes.add(null);
  Future<void> dispose() => _changes.close();

  @override
  Stream<void> get changedStream => _changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountOperations implements SourceAccountOperations {
  @override
  bool get isLogged => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRuntimeOperations implements SourceRuntimeOperations {
  void Function(int received, int total)? initProgress;
  final ensureSourceKeys = <String?>[];
  String? writtenSource;
  var reloadCalls = 0;

  @override
  Future<void> init({
    void Function(int received, int total)? onSourceDownloadProgress,
    bool prewarm = false,
  }) async {
    initProgress = onSourceDownloadProgress;
  }

  @override
  Future<void> ensureInitialized({String? sourceKey}) async {
    ensureSourceKeys.add(sourceKey);
  }

  @override
  Future<void> writeLocalActiveSource(String content) async {
    writtenSource = content;
  }

  @override
  Future<void> reloadFromLocalSourceFiles() async {
    reloadCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
