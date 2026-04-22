import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_mode.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final validPngBytes = Uint8List.fromList(const <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0xF8,
    0xCF,
    0xC0,
    0x00,
    0x00,
    0x03,
    0x01,
    0x01,
    0x00,
    0x18,
    0xDD,
    0x8D,
    0xB1,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  group('ReaderRuntimeState', () {
    test('applySettingsSnapshot updates settings and rebuilds spread keys', () {
      final state = ReaderRuntimeState()..applyImages(['a', 'b', 'c', 'd']);

      state.applySettingsSnapshot(
        const ReaderSettingsSnapshot(
          readerMode: ReaderMode.rightToLeft,
          doublePageMode: true,
          tapToTurnPage: true,
          volumeButtonTurnPage: true,
          immersiveMode: false,
          keepScreenOn: false,
          customBrightness: true,
          brightnessValue: 0.8,
          pageIndicator: true,
          pinchToZoom: true,
          longPressToSave: true,
        ),
      );

      expect(state.readerMode, ReaderMode.rightToLeft);
      expect(state.doublePageMode, isTrue);
      expect(state.tapToTurnPage, isTrue);
      expect(state.volumeButtonTurnPage, isTrue);
      expect(state.immersiveMode, isFalse);
      expect(state.keepScreenOn, isFalse);
      expect(state.customBrightness, isTrue);
      expect(state.brightnessValue, 0.8);
      expect(state.pageIndicator, isTrue);
      expect(state.pinchToZoom, isTrue);
      expect(state.longPressToSave, isTrue);
      expect(state.readerSpreadSize, 2);
      expect(state.readerSpreadCount, 2);
      expect(state.itemKeys, hasLength(2));
    });

    test('applyImages resets transient session state', () {
      final state = ReaderRuntimeState()
        ..currentPageIndex = 2
        ..controlsVisible = true
        ..sliderDragging = true
        ..sliderDragValue = 2
        ..lastSliderHapticPageIndex = 2
        ..loadingImages = true
        ..loadImagesError = 'boom'
        ..isZoomed = true
        ..zoomInteracting = true
        ..activePointerCount = 3;

      state.applyImages(['a', 'b', 'c']);

      expect(state.images, ['a', 'b', 'c']);
      expect(state.currentPageIndex, 0);
      expect(state.loadingImages, isFalse);
      expect(state.loadImagesError, isNull);
      expect(state.isZoomed, isFalse);
      expect(state.zoomInteracting, isFalse);
      expect(state.activePointerCount, 0);
      expect(state.sliderDragging, isFalse);
      expect(state.sliderDragValue, 0);
      expect(state.lastSliderHapticPageIndex, isNull);
      expect(state.pageIndexNotifier.value, 0);
      expect(state.itemKeys, hasLength(3));
    });
  });

  group('ReaderImagePipelineState', () {
    test(
      'resetForImages rebuilds lookup and clears transient pipeline state',
      () {
        final state = ReaderImagePipelineState()
          ..providerCache['old'] = const AssetImage('old')
          ..providerFutureCache['old'] = Future.value(const AssetImage('old'))
          ..imageAspectRatioCache['old'] = 1.2
          ..retryingImageUrls.add('old')
          ..activeUnscrambleTasks = 2
          ..prefetchAheadRunning = true
          ..queuedPrefetchAheadIndex = 5;

        state.resetForImages(['a', 'b']);

        expect(state.providerCache, isEmpty);
        expect(state.providerFutureCache, isEmpty);
        expect(state.imageAspectRatioCache, isEmpty);
        expect(state.retryingImageUrls, isEmpty);
        expect(state.activeUnscrambleTasks, 0);
        expect(state.prefetchAheadRunning, isFalse);
        expect(state.queuedPrefetchAheadIndex, isNull);
        expect(state.imageIndexMap, {'a': 0, 'b': 1});
      },
    );
  });

  group('ReaderImagePipelineController', () {
    testWidgets(
      'retryImage clears caches and bypasses disk cache for the retried image',
      (tester) async {
        final runtimeState = ReaderRuntimeState()..applyImages(['retry-url']);
        final pipelineState = ReaderImagePipelineState()
          ..providerCache['retry-url'] = const AssetImage('old')
          ..providerFutureCache['retry-url'] = Future.value(
            const AssetImage('old'),
          );
        final diagnosticsState = ReaderDiagnosticsState();
        final zoomController = TransformationController();
        final useDiskCacheCalls = <bool>[];
        final evictedMemoryUrls = <String>[];
        final evictedDiskUrls = <String>[];
        late ReaderImagePipelineController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                controller = ReaderImagePipelineController(
                  runtimeState: runtimeState,
                  pipelineState: pipelineState,
                  diagnosticsState: diagnosticsState,
                  zoomController: zoomController,
                  context: () => context,
                  isMounted: () => true,
                  updateState: (update) => update(),
                  logEvent:
                      (
                        title, {
                        level = 'info',
                        source = 'reader_ui',
                        content,
                      }) {},
                  logPayload: ([extra]) => extra ?? <String, dynamic>{},
                  logVisiblePageChange: ({required index, required trigger}) {},
                  noImageModeEnabled: () => false,
                  comicId: 'comic',
                  epId: 'ep',
                  loadImagesErrorBuilder: (error) => '$error',
                  imageProviderBuilder:
                      (url, {bool useDiskCache = true}) async {
                        useDiskCacheCalls.add(useDiskCache);
                        return MemoryImage(validPngBytes);
                      },
                  evictImageBytesFromMemory: (urls) {
                    evictedMemoryUrls.addAll(urls);
                  },
                  evictImageCacheEntries: (urls) async {
                    evictedDiskUrls.addAll(urls);
                  },
                  precacheImageCallback: (_) async {},
                );

                return const SizedBox.shrink();
              },
            ),
          ),
        );

        await controller.retryImage('retry-url');
        await tester.pump();

        expect(evictedMemoryUrls, ['retry-url']);
        expect(evictedDiskUrls, ['retry-url']);
        expect(useDiskCacheCalls, [isFalse]);
        expect(pipelineState.providerCache.keys, ['retry-url']);
        expect(pipelineState.providerFutureCache.keys, ['retry-url']);
        expect(pipelineState.retryingImageUrls, isEmpty);
      },
    );
  });

  group('ReaderNavigationController', () {
    test(
      'center tap toggles controls and edge taps request page navigation',
      () async {
        final state = ReaderRuntimeState()
          ..applyImages(['a', 'b', 'c'])
          ..readerMode = ReaderMode.rightToLeft
          ..tapToTurnPage = true
          ..currentPageIndex = 1;
        state.setDisplayedPageIndex(1);

        var toggled = 0;
        final controller = ReaderNavigationController(
          runtimeState: state,
          diagnosticsState: ReaderDiagnosticsState(),
          scrollController: ScrollController(),
          pageController: PageController(),
          isMounted: () => true,
          updateState: (update) => update(),
          logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
          logPayload: ([extra]) => extra ?? <String, dynamic>{},
          logVisiblePageChange: ({required index, required trigger}) {},
          resetZoomImmediately: ({reason = 'unspecified'}) {},
          prefetchAround: (_) {},
          requestPrefetchAhead: (_) {},
          noImageModeEnabled: () => false,
          toggleControlsVisibility: () {
            toggled++;
          },
        );

        await controller.handleTapUp(
          TapUpDetails(
            localPosition: Offset(50, 0),
            kind: PointerDeviceKind.touch,
          ),
          100,
        );
        expect(toggled, 1);
        expect(state.pageIndexNotifier.value, 1);

        await controller.handleTapUp(
          TapUpDetails(
            localPosition: Offset(10, 0),
            kind: PointerDeviceKind.touch,
          ),
          100,
        );
        expect(state.pageIndexNotifier.value, 0);

        state.currentPageIndex = 0;
        state.setDisplayedPageIndex(0);
        await controller.handleTapUp(
          TapUpDetails(
            localPosition: Offset(90, 0),
            kind: PointerDeviceKind.touch,
          ),
          100,
        );
        expect(state.pageIndexNotifier.value, 1);
      },
    );
  });
}
