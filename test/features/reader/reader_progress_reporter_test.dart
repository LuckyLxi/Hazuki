import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/support/reader_progress_reporter.dart';

void main() {
  testWidgets(
    'reports one-based images, throttles latest and flushes last position',
    (tester) async {
      final events = <Map<String, Object>>[];
      final reporter = ReaderProgressReporter(
        comicId: 'comic',
        chapterId: 'chapter',
        send: (p) async {
          events.add(p);
        },
      );
      reporter.observe(firstImage: 0, lastImage: 1, totalPages: 7);
      await tester.pump();
      expect(events.single['page'], 1);
      expect(events.single['visiblePages'], [1, 2]);
      reporter.observe(firstImage: 2, lastImage: 3, totalPages: 7);
      reporter.observe(firstImage: 4, lastImage: 5, totalPages: 7);
      await tester.pump(const Duration(seconds: 4));
      expect(events, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(events.last['page'], 5);
      reporter.observe(firstImage: 6, lastImage: 6, totalPages: 7);
      reporter.close('chapter');
      await tester.pump();
      expect(events.last['page'], 7);
      expect(events.last['reason'], 'chapter');
      await tester.pump(const Duration(seconds: 10));
      expect(events, hasLength(3));
    },
  );

  testWidgets('empty chapters do not report and async failures do not escape', (
    tester,
  ) async {
    var calls = 0;
    final reporter = ReaderProgressReporter(
      comicId: 'c',
      chapterId: 'e',
      send: (_) async {
        calls++;
        throw StateError('offline');
      },
    );
    reporter.observe(firstImage: 0, lastImage: 0, totalPages: 0);
    reporter.flush('exit');
    expect(calls, 0);
    reporter.observe(firstImage: 0, lastImage: 0, totalPages: 1);
    await tester.pump();
    reporter.flush('background');
    reporter.close('exit');
    await tester.pump();
    expect(calls, 3);
    expect(tester.takeException(), isNull);
  });
}
