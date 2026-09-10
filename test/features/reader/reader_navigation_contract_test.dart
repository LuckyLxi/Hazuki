import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/state/reader_navigation_state.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/support/reader_navigation_prefetch.dart';

void main() {
  test('navigation state keeps page normalization and spread mapping', () {
    final runtime = ReaderRuntimeState()..applyImages(['a', 'b', 'c']);
    addTearDown(runtime.dispose);
    runtime.updateSettings(doublePageMode: true);
    final ReaderNavigationState navigation = runtime;
    navigation.setCurrentPageIndex(99);
    expect(navigation.imageCount, 3);
    expect(navigation.readerSpreadCount, 2);
    expect(navigation.currentPageIndex, 1);
    expect(navigation.spreadStartIndex(1), 2);
    expect(runtime.pageIndexNotifier.value, 1);
    navigation.setCurrentPageIndex(-1);
    expect(navigation.currentPageIndex, 0);
    expect(() => navigation.itemKeys.clear(), throwsUnsupportedError);
  });

  test(
    'prefetch handles the target before ahead work and checks current mode',
    () {
      var noImages = false;
      final calls = <String>[];
      final prefetch = ReaderNavigationPrefetch(
        noImageModeEnabled: () => noImages,
        prefetchAround: (index) => calls.add('around:$index'),
        requestPrefetchAhead: (index) => calls.add('ahead:$index'),
      );
      prefetch.onPageTargetChanged(2);
      expect(calls, ['around:2', 'ahead:2']);
      noImages = true;
      prefetch.onPageTargetChanged(3);
      expect(calls.length, 2);
      noImages = false;
      prefetch.onPageTargetChanged(3);
      expect(calls, ['around:2', 'ahead:2', 'around:3', 'ahead:3']);
    },
  );
}
