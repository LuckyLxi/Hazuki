import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/state/reader_navigation_state.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';

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
}
