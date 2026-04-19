import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/pages/reader/reader_diagnostics_support.dart';
import 'package:hazuki/pages/reader/reader_image_pipeline_state.dart';
import 'package:hazuki/pages/reader/reader_mode.dart';
import 'package:hazuki/pages/reader/reader_navigation_controller.dart';
import 'package:hazuki/pages/reader/reader_runtime_state.dart';
import 'package:hazuki/pages/reader/reader_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
