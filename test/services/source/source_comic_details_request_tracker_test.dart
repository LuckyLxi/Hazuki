import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/comic/source_comic_details_cache.dart';

void main() {
  test('only the newest request can update a comic detail cache entry', () {
    final tracker = SourceComicDetailsRequestTracker();
    final first = tracker.begin('copy_manga:comic');
    final refreshed = tracker.begin('copy_manga:comic');

    expect(tracker.isCurrent('copy_manga:comic', first), isFalse);
    expect(tracker.isCurrent('copy_manga:comic', refreshed), isTrue);

    tracker.complete('copy_manga:comic', first);
    expect(tracker.isCurrent('copy_manga:comic', refreshed), isTrue);

    tracker.complete('copy_manga:comic', refreshed);
    expect(tracker.isCurrent('copy_manga:comic', refreshed), isFalse);
  });
}
