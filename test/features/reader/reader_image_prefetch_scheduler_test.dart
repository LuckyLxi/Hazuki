import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/support/reader_image_prefetch_scheduler.dart';

void main() {
  late ReaderImagePipelineState state;
  late List<String> images;
  late List<(String, bool)> providers;
  late List<String> downloads;
  late List<String> evictions;
  late ReaderImagePrefetchScheduler scheduler;
  Future<void> Function(String)? download;

  setUp(() {
    images = List.generate(60, (index) => '$index');
    state = ReaderImagePipelineState()..resetForImages(images);
    providers = [];
    downloads = [];
    evictions = [];
    download = null;
    scheduler = ReaderImagePrefetchScheduler(
      state: state,
      windowFor: (index) => ReaderImagePrefetchWindow(
        images: images,
        anchorImageIndex: index * 2,
        visibleImageIndices: [index * 2, index * 2 + 1],
        spreadSize: 2,
      ),
      getImageProvider: (url, {bool priority = false}) async {
        providers.add((url, priority));
        return const AssetImage('image');
      },
      isLocalImagePath: (url) => url.startsWith('local'),
      downloadImageBytes: (url) {
        downloads.add(url);
        return download?.call(url) ?? Future.value();
      },
      evictImageBytesFromMemory: (urls) => evictions.addAll(urls),
    );
  });
  tearDown(() => state.dispose());

  test(
    'prioritizes both visible pages and skips cached neighbor requests',
    () async {
      state.providerCache['0'] = const AssetImage('cached');
      state.providerFutureCache['1'] = Future.value(
        const AssetImage('loading'),
      );
      scheduler.prefetchAround(2);
      await Future<void>.delayed(Duration.zero);
      expect(providers.take(2), [('4', true), ('5', true)]);
      expect(providers.skip(2).every((entry) => !entry.$2), isTrue);
      expect(providers.map((entry) => entry.$1), isNot(contains('0')));
      expect(providers.map((entry) => entry.$1), isNot(contains('1')));
    },
  );

  test(
    'evicts providers, pending requests and bytes outside the retained range',
    () {
      for (final url in ['7', '8', '44', '45', 'unknown']) {
        state.providerCache[url] = const AssetImage('cached');
        state.providerFutureCache[url] = Future.value(
          const AssetImage('loading'),
        );
        state.priorityProviderRequests.add(url);
      }
      scheduler.prefetchAround(10);
      expect(state.providerCache.keys, ['8', '44']);
      expect(state.providerFutureCache.keys, ['8', '44']);
      expect(state.priorityProviderRequests, {'8', '44'});
      expect(evictions, [...images.take(8), ...images.skip(45)]);
    },
  );

  test(
    'coalesces rapid page changes into the latest pending ahead range',
    () async {
      final firstBatch = Completer<void>();
      download = (_) => firstBatch.future;
      scheduler.requestPrefetchAhead(0);
      scheduler.requestPrefetchAhead(4);
      scheduler.requestPrefetchAhead(8);
      expect(downloads, ['2', '3', '4', '5', '6', '7']);
      download = null;
      firstBatch.complete();
      await Future<void>.delayed(Duration.zero);
      expect(downloads.skip(6), ['18', '19', '20', '21', '22', '23']);
      expect(state.prefetchAheadRunning, isFalse);
      expect(state.queuedPrefetchAheadIndex, isNull);
    },
  );

  test(
    'local and blank URLs skip network prefetch and errors stay best effort',
    () async {
      images = ['0', '1', 'local:2', '', '4'];
      download = (_) => Future.error(StateError('offline'));
      scheduler.requestPrefetchAhead(0);
      await Future<void>.delayed(Duration.zero);
      expect(downloads, ['4']);
      expect(providers.map((entry) => entry.$1), ['local:2', '4']);
      expect(state.prefetchAheadRunning, isFalse);
    },
  );

  test(
    'disposal drops queued ahead work after in-flight requests finish',
    () async {
      final firstBatch = Completer<void>();
      download = (_) => firstBatch.future;
      scheduler.requestPrefetchAhead(0);
      scheduler.requestPrefetchAhead(8);
      state.dispose();
      firstBatch.complete();
      await Future<void>.delayed(Duration.zero);
      expect(downloads, ['2', '3', '4', '5', '6', '7']);
      expect(state.prefetchAheadRunning, isFalse);
      expect(state.queuedPrefetchAheadIndex, isNull);
    },
  );
}
