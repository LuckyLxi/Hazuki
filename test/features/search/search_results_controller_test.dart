import '../../support/fake_source_task_control.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hazuki/features/search/support/search_contracts.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/features/search/state/search_results_controller.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import '../../support/test_service_locator.dart';

class _Source extends Mock implements SourceSearchGateway {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await ensureTestServiceLocator();
  });

  test('forwards source service changes until disposed', () {
    final controller = SearchResultsController(
      taskControl: FakeSourceTaskControl(),
      initialOrder: 'mr',
      sourceService: sl<SourceSearchGateway>(),
    );
    var notifications = 0;
    controller.addListener(() {
      notifications++;
    });

    // ignore: invalid_use_of_protected_member
    sl<SourceRuntimeAssembly>().testing.notifyRuntimeView();

    expect(notifications, 1);

    controller.dispose();
    // ignore: invalid_use_of_protected_member
    sl<SourceRuntimeAssembly>().testing.notifyRuntimeView();

    expect(notifications, 1);
  });

  test(
    'selection and requests use plugin defaults and reset on source change',
    () async {
      final source = _Source();
      var activeKey = 'custom';
      late VoidCallback sourceChanged;
      when(() => source.activeSourceKey).thenAnswer((_) => activeKey);
      when(() => source.allowedSources).thenReturn(const [
        SourceCatalogEntry(
          key: 'custom',
          name: 'Custom',
          fileName: 'custom.js',
          presentation: {
            'searchOrders': {'popular': 'Popular', 'recent': 'Recent'},
            'searchDefaultOrder': 'recent',
          },
        ),
        SourceCatalogEntry(
          key: 'other',
          name: 'Other',
          fileName: 'other.js',
          presentation: {
            'searchOrders': {'score': 'Score'},
          },
        ),
        SourceCatalogEntry(key: 'plain', name: 'Plain', fileName: 'plain.js'),
      ]);
      when(() => source.addListener(any())).thenAnswer((call) {
        sourceChanged = call.positionalArguments.single as VoidCallback;
      });
      final requests = <String>[];
      final controller = SearchResultsController(
        taskControl: FakeSourceTaskControl(),
        initialOrder: 'mr',
        sourceService: source,
        searchPageLoader:
            ({required keyword, required page, required order}) async {
              requests.add(order);
              return const SearchComicsResult(
                comics: [
                  ExploreComic(id: '1', title: 'Test', subTitle: '', cover: ''),
                ],
                maxPage: 1,
              );
            },
      );
      addTearDown(controller.dispose);
      final messages = SearchMessages(
        timeout: 'timeout',
        failed: (error) => error,
      );
      expect(controller.searchOrder, 'recent');
      await controller.search(messages, keyword: 'test', page: 1);
      controller.setSearchOrder(' popular ');
      expect(controller.searchOrder, 'popular');
      await controller.search(messages, keyword: 'test', page: 1);
      controller.setSearchOrder('unknown');
      expect(controller.searchOrder, 'recent');
      activeKey = 'other';
      sourceChanged();
      expect(controller.searchOrder, 'score');
      await controller.search(messages, keyword: 'test', page: 1);
      activeKey = 'plain';
      sourceChanged();
      expect(controller.searchOrder, '');
      await controller.search(messages, keyword: 'test', page: 1);
      expect(requests, ['recent', 'popular', 'score', '']);
    },
  );

  test(
    'a runtime failure is shown without automatic retry while ordinary errors retry',
    () async {
      final source = _Source();
      when(() => source.activeSourceKey).thenReturn('custom');
      when(() => source.allowedSources).thenReturn(const [
        SourceCatalogEntry(key: 'custom', name: 'Custom', fileName: 'c.js'),
      ]);
      Object failure = const SourceRuntimeFailed(
        'runtime',
        SourceRuntimeFailureKind.internalJob,
      );
      var calls = 0;
      final controller = SearchResultsController(
        taskControl: FakeSourceTaskControl(),
        initialOrder: 'mr',
        sourceService: source,
        searchPageLoader:
            ({required keyword, required page, required order}) async {
              calls++;
              throw failure;
            },
      );
      addTearDown(controller.dispose);
      final messages = SearchMessages(
        timeout: 'timeout',
        failed: (error) => error,
      );
      await controller.search(messages, keyword: 'test', page: 1);
      // 运行时故障不能被重试重放到重建后的实例，但要显示错误而非静默。
      expect(calls, 1);
      expect(
        controller.searchErrorMessage,
        'source_runtime_failed:internalJob',
      );

      calls = 0;
      failure = Exception('ordinary');
      await controller.search(messages, keyword: 'again', page: 1);
      expect(calls, greaterThan(1));
    },
  );
}
