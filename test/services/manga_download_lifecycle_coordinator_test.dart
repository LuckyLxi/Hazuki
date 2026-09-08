import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/manga_download/manga_download_lifecycle_coordinator.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';

class _Harness {
  _Harness(WidgetTester tester, {required bool isAndroid}) {
    coordinator = MangaDownloadLifecycleCoordinator(
      isAndroid: isAndroid,
      hasActiveDownloads: () => active,
      startForegroundService: () async {
        starts++;
      },
      stopForegroundService: () async {
        stops++;
      },
      processQueue: () async {
        queueRuns++;
      },
      now: tester.binding.clock.now,
    );
  }

  late final MangaDownloadLifecycleCoordinator coordinator;
  bool active = true;
  int starts = 0;
  int stops = 0;
  int queueRuns = 0;
}

void main() {
  testWidgets('Android keeps background downloads active until detached', (
    tester,
  ) async {
    final h = _Harness(tester, isAndroid: true);
    addTearDown(h.coordinator.dispose);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      h.coordinator.handleAppLifecycleState(state);
      expect(h.coordinator.shouldSuspendDownloads, isFalse);
    }
    expect(h.starts, 1);
    h.active = false;
    h.coordinator.handleAppLifecycleState(AppLifecycleState.paused);
    expect(h.starts, 1);
    h.coordinator.handleAppLifecycleState(AppLifecycleState.detached);
    expect(h.coordinator.shouldSuspendDownloads, isTrue);
    expect(h.coordinator.shouldRecoverTransientNetworkError, isTrue);
  });

  testWidgets('other platforms suspend on each non-resumed state', (
    tester,
  ) async {
    for (final state in AppLifecycleState.values.where(
      (s) => s != AppLifecycleState.resumed,
    )) {
      final h = _Harness(tester, isAndroid: false);
      expect(h.coordinator.shouldSuspendDownloads, isFalse);
      expect(h.coordinator.shouldRecoverTransientNetworkError, isFalse);
      h.coordinator.handleAppLifecycleState(state);
      expect(h.coordinator.shouldSuspendDownloads, isTrue);
      expect(h.coordinator.shouldRecoverTransientNetworkError, isTrue);
      expect(h.starts, 0);
      h.coordinator.dispose();
    }
  });

  testWidgets('resume delays the queue and bounds transient retry grace', (
    tester,
  ) async {
    final h = _Harness(tester, isAndroid: false);
    addTearDown(h.coordinator.dispose);
    h.coordinator.handleAppLifecycleState(AppLifecycleState.paused);
    h.coordinator.handleAppLifecycleState(AppLifecycleState.resumed);
    expect(h.coordinator.shouldSuspendDownloads, isFalse);
    expect(h.coordinator.shouldRecoverTransientNetworkError, isTrue);
    expect(h.stops, 1);
    await tester.pump(const Duration(milliseconds: 1199));
    expect(h.queueRuns, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(h.queueRuns, 1);
    await tester.pump(const Duration(milliseconds: 2799));
    expect(h.coordinator.shouldRecoverTransientNetworkError, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(h.coordinator.shouldRecoverTransientNetworkError, isFalse);
  });

  testWidgets('repeated resume replaces the timer and grace deadline', (
    tester,
  ) async {
    final h = _Harness(tester, isAndroid: true);
    addTearDown(h.coordinator.dispose);
    h.coordinator.handleAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    h.coordinator.handleAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 200));
    expect(h.queueRuns, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(h.queueRuns, 1);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(h.coordinator.shouldRecoverTransientNetworkError, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(h.coordinator.shouldRecoverTransientNetworkError, isFalse);
    expect(h.queueRuns, 1);
  });

  testWidgets('suspension cancels pending queue resumption', (tester) async {
    for (final isAndroid in [false, true]) {
      final h = _Harness(tester, isAndroid: isAndroid);
      h.coordinator.handleAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 600));
      h.coordinator.handleAppLifecycleState(
        isAndroid ? AppLifecycleState.detached : AppLifecycleState.paused,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(h.queueRuns, 0);
      expect(h.coordinator.shouldSuspendDownloads, isTrue);
      h.coordinator.dispose();
    }
  });

  testWidgets('Android pause keeps a scheduled resume alive', (tester) async {
    final h = _Harness(tester, isAndroid: true);
    addTearDown(h.coordinator.dispose);
    h.coordinator.handleAppLifecycleState(AppLifecycleState.resumed);
    h.coordinator.handleAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(h.queueRuns, 1);
    expect(h.starts, 1);
  });

  testWidgets('dispose cancels timers and ignores later lifecycle events', (
    tester,
  ) async {
    final h = _Harness(tester, isAndroid: true);
    h.coordinator.handleAppLifecycleState(AppLifecycleState.resumed);
    h.coordinator.dispose();
    h.coordinator.handleAppLifecycleState(AppLifecycleState.resumed);
    h.coordinator.handleAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    expect(h.queueRuns, 0);
    expect(h.stops, 1);
    expect(h.starts, 0);
  });

  testWidgets('download service disposes its pending lifecycle timer', (
    tester,
  ) async {
    final service = MangaDownloadService();
    service.handleAppLifecycleState(AppLifecycleState.resumed);
    service.dispose();
    // A live timer here is reported by the widget test timer invariant.
  });
}
