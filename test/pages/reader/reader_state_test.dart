import 'dart:async';
import 'package:hazuki/app/service_locator.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_mode.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/support/reader_page_context.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/features/reader/support/reader_settings_controller.dart';
import 'package:hazuki/features/reader/support/reader_source_image_quality_settings.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';
import 'package:hazuki/features/settings/state/reading_settings_controller.dart';
import 'package:hazuki/features/reader/view/reader_overlay_layout.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';
import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await ensureTestServiceLocator();
  });
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

  group('ReaderSettingsController', () {
    testWidgets(
      'saves reading mode and syncs the current image after layout changes',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(const SizedBox.shrink());
        final runtimeState = ReaderRuntimeState()
          ..applyImages(['a', 'b', 'c', 'd'])
          ..currentPageIndex = 1;
        runtimeState.setDisplayedPageIndex(1);
        final diagnosticsState = ReaderDiagnosticsState();
        final scrollController = ScrollController();
        final pageController = PageController();
        final focusNode = FocusNode();
        final transformationController = TransformationController(
          Matrix4.diagonal3Values(2.0, 2.0, 1.0),
        );
        final resetAnimController = AnimationController(vsync: tester);
        final settingsStore = ReaderSettingsStore();
        final logEvents = <String>[];

        addTearDown(scrollController.dispose);
        addTearDown(pageController.dispose);
        addTearDown(focusNode.dispose);
        addTearDown(transformationController.dispose);
        addTearDown(resetAnimController.dispose);
        addTearDown(runtimeState.pageIndexNotifier.dispose);

        final zoomController = ReaderZoomController(
          transformationController: transformationController,
          resetAnimController: resetAnimController,
          runtimeState: runtimeState,
          isMounted: () => true,
          updateState: (update) => update(),
          logEvent: (title, {level = 'info', source = 'reader_ui', content}) {
            logEvents.add(title);
          },
          logPayload: ([extra]) => extra ?? <String, dynamic>{},
        );
        final navigationController = ReaderNavigationController(
          runtimeState: runtimeState,
          diagnosticsState: diagnosticsState,
          scrollController: scrollController,
          pageController: pageController,
          isMounted: () => true,
          updateState: (update) => update(),
          logEvent: (title, {level = 'info', source = 'reader_ui', content}) {
            logEvents.add(title);
          },
          logPayload: ([extra]) => extra ?? <String, dynamic>{},
          logVisiblePageChange: ({required index, required trigger}) {},
          resetZoomImmediately: zoomController.resetZoomImmediately,
          prefetchAround: (_) {},
          requestPrefetchAhead: (_) {},
          noImageModeEnabled: () => false,
          toggleControlsVisibility: () {},
        );
        final sessionController = ReaderSessionController(
          runtimeState: runtimeState,
          displayBridge: ReaderDisplayBridge(
            onVolumeButtonPressed: (_) async {},
          ),
          settingsStore: settingsStore,
          scrollController: scrollController,
          pageController: pageController,
          readerKeyFocusNode: focusNode,
          zoomController: transformationController,
          applyInitialImages: (_, {required trigger}) {},
          loadChapterImages: ({trigger = 'manual'}) async {},
          onNoImageModeChanged: () {},
          isMounted: () => true,
          updateState: (update) => update(),
          logEvent: (title, {level = 'info', source = 'reader_ui', content}) {
            logEvents.add(title);
          },
          logPayload: ([extra]) => extra ?? <String, dynamic>{},
          onScrollPositionChanged: () {},
          onZoomChanged: () {},
          comicId: 'comic',
          epId: 'ep',
          chapterTitle: 'Chapter 1',
          chapterIndex: 0,
          widgetImages: const [],
          sourceService: sl<HazukiSourceService>(),
        );
        final controller = ReaderSettingsController(
          runtimeState: runtimeState,
          settingsStore: settingsStore,
          navigationController: navigationController,
          sessionController: sessionController,
          zoomController: zoomController,
          updateState: (update) => update(),
          logEvent: (title, {level = 'info', source = 'reader_ui', content}) {
            logEvents.add(title);
          },
          logPayload: ([extra]) => extra ?? <String, dynamic>{},
        );

        await controller.updateReaderMode(ReaderMode.rightToLeft);
        WidgetsBinding.instance.scheduleFrame();
        await tester.pump();

        final prefs = await SharedPreferences.getInstance();
        expect(runtimeState.readerMode, ReaderMode.rightToLeft);
        expect(
          prefs.getString(ReaderSettingsStore.readingModeKey),
          ReaderMode.rightToLeft.prefsValue,
        );
        expect(transformationController.value.getMaxScaleOnAxis(), 1);
        expect(logEvents, contains('Reader mode changed'));

        await controller.toggleDoublePageMode(true);
        WidgetsBinding.instance.scheduleFrame();
        await tester.pump();

        expect(runtimeState.doublePageMode, isTrue);
        expect(prefs.getBool(ReaderSettingsStore.doublePageModeKey), isTrue);
        expect(runtimeState.currentPageIndex, 0);
        expect(runtimeState.readerSpreadSize, 2);
        expect(logEvents, contains('Reader double page mode toggled'));
      },
    );
  });

  group('ReaderSessionController', () {
    testWidgets('turning off immersive mode shows system overlays', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const SizedBox.shrink());
      final platformCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            platformCalls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await ReaderDisplayBridge.controller.apply(
        immersiveMode: false,
        keepScreenOn: false,
        customBrightness: false,
        brightnessValue: 0.5,
      );

      final overlayCalls = platformCalls.where(
        (call) => call.method == 'SystemChrome.setEnabledSystemUIOverlays',
      );
      expect(overlayCalls, isNotEmpty);
      expect(
        overlayCalls.last.arguments,
        containsAll(['SystemUiOverlay.top', 'SystemUiOverlay.bottom']),
      );
    });

    testWidgets(
      'does not reapply immersive mode after the reader closes',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          ReaderSettingsStore.immersiveModeKey: true,
        });
        await tester.pumpWidget(const SizedBox.shrink());
        final platformCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              platformCalls.add(call);
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final runtimeState = ReaderRuntimeState();
        final scrollController = ScrollController();
        final pageController = PageController();
        final focusNode = FocusNode();
        final transformationController = TransformationController();
        final sessionController = ReaderSessionController(
          runtimeState: runtimeState,
          displayBridge: ReaderDisplayBridge(
            onVolumeButtonPressed: (_) async {},
          ),
          settingsStore: const ReaderSettingsStore(),
          scrollController: scrollController,
          pageController: pageController,
          readerKeyFocusNode: focusNode,
          zoomController: transformationController,
          applyInitialImages: (_, {required trigger}) {},
          loadChapterImages: ({trigger = 'manual'}) async {},
          onNoImageModeChanged: () {},
          isMounted: () => true,
          updateState: (update) => update(),
          logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
          logPayload: ([extra]) => extra ?? <String, dynamic>{},
          onScrollPositionChanged: () {},
          onZoomChanged: () {},
          comicId: 'comic',
          epId: 'ep',
          chapterTitle: 'Chapter 1',
          chapterIndex: 0,
          widgetImages: const [],
          sourceService: sl<HazukiSourceService>(),
        );

        sessionController.initialize();
        sessionController.dispose();
        await tester.pump();

        final immersiveModeCalls = platformCalls.where(
          (call) =>
              call.method == 'SystemChrome.setEnabledSystemUIMode' &&
              call.arguments == 'SystemUiMode.immersiveSticky',
        );
        final overlayRestoreCalls = platformCalls.where(
          (call) => call.method == 'SystemChrome.setEnabledSystemUIOverlays',
        );
        expect(overlayRestoreCalls, isNotEmpty);
        expect(
          immersiveModeCalls,
          isEmpty,
        );
        expect(
          overlayRestoreCalls.last.arguments,
          containsAll(['SystemUiOverlay.top', 'SystemUiOverlay.bottom']),
        );
      },
    );
  });

  group('ReaderSourceImageQualitySettings', () {
    test('normalizes source image quality values', () {
      expect(
        ReaderSourceImageQualitySettings.normalizeCopyMangaImageQuality('800'),
        '800',
      );
      expect(
        ReaderSourceImageQualitySettings.normalizeCopyMangaImageQuality('1200'),
        '1200',
      );
      expect(
        ReaderSourceImageQualitySettings.normalizeCopyMangaImageQuality('bad'),
        '1500',
      );
      expect(
        ReaderSourceImageQualitySettings.normalizePicacgImageQuality(
          'original',
        ),
        'original',
      );
      expect(
        ReaderSourceImageQualitySettings.normalizePicacgImageQuality('medium'),
        'medium',
      );
      expect(
        ReaderSourceImageQualitySettings.normalizePicacgImageQuality(null),
        'original',
      );
    });
  });

  group('ReadingSettingsController', () {
    test('persists reading settings to existing preference keys', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ReadingSettingsController(
        sourceService: sl<HazukiSourceService>(),
      );
      addTearDown(controller.dispose);

      await controller.loadSettings();
      await controller.updateReaderMode(ReaderMode.rightToLeft);
      await controller.toggleDoublePageMode(true);
      await controller.toggleTapToTurnPage(true);
      await controller.toggleVolumeButtonTurnPage(true);
      await controller.toggleImmersiveMode(false);
      await controller.toggleKeepScreenOn(false);
      await controller.toggleCustomBrightness(true);
      await controller.updateBrightness(1.4);
      await controller.togglePageIndicator(true);
      await controller.togglePinchToZoom(true);
      await controller.toggleLongPressToSave(true);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(ReaderSettingsStore.readingModeKey),
        ReaderMode.rightToLeft.prefsValue,
      );
      expect(prefs.getBool(ReaderSettingsStore.doublePageModeKey), isTrue);
      expect(prefs.getBool(ReaderSettingsStore.tapToTurnPageKey), isTrue);
      expect(
        prefs.getBool(ReaderSettingsStore.volumeButtonTurnPageKey),
        isTrue,
      );
      expect(prefs.getBool(ReaderSettingsStore.immersiveModeKey), isFalse);
      expect(prefs.getBool(ReaderSettingsStore.keepScreenOnKey), isFalse);
      expect(prefs.getBool(ReaderSettingsStore.customBrightnessKey), isTrue);
      expect(prefs.getDouble(ReaderSettingsStore.brightnessValueKey), 1.0);
      expect(prefs.getBool(ReaderSettingsStore.pageIndicatorKey), isTrue);
      expect(prefs.getBool(ReaderSettingsStore.pinchToZoomKey), isTrue);
      expect(prefs.getBool(ReaderSettingsStore.longPressToSaveKey), isTrue);
    });
  });

  group('ReaderPageContext', () {
    test('copyForChapter preserves callbacks, source, theme, and title', () {
      Future<void> onFavorite(BuildContext context) async {}
      Widget commentsBuilder({
        required String comicId,
        String? subId,
        required String sourceKey,
        ScrollController? scrollController,
        Future<void> Function()? onRequestTabFullscreen,
      }) {
        return const SizedBox.shrink();
      }

      final theme = ThemeData.dark();
      final context = ReaderPageContext(
        title: 'Hazuki',
        chapterTitle: 'Chapter 1',
        comicId: 'comic',
        epId: 'ep-1',
        chapterIndex: 0,
        images: const ['a'],
        sourceKey: 'source',
        comicTheme: theme,
        onFavoriteRequested: onFavorite,
        commentsWidgetBuilder: commentsBuilder,
      );

      final next = context.copyForChapter(
        epId: 'ep-2',
        chapterTitle: 'Chapter 2',
        chapterIndex: 1,
      );

      expect(next.title, 'Hazuki');
      expect(next.comicId, 'comic');
      expect(next.sourceKey, 'source');
      expect(next.comicTheme, same(theme));
      expect(next.onFavoriteRequested, same(onFavorite));
      expect(next.commentsWidgetBuilder, same(commentsBuilder));
      expect(next.epId, 'ep-2');
      expect(next.chapterTitle, 'Chapter 2');
      expect(next.chapterIndex, 1);
      expect(next.images, isEmpty);
    });
  });

  group('ReaderOverlayLayout', () {
    test('reserves room for the unified bottom controls', () {
      expect(
        ReaderOverlayLayout.bottomControlsReservedHeight,
        greaterThanOrEqualTo(ReaderOverlayLayout.bottomControlsHeight),
      );
      expect(
        ReaderOverlayLayout.bottomControlsHeight,
        greaterThan(ReaderOverlayLayout.bottomControlsButtonSize),
      );
      expect(
        ReaderOverlayLayout.bottomControlsHeight,
        greaterThanOrEqualTo(
          ReaderOverlayLayout.bottomControlsButtonSize * 2 +
              ReaderOverlayLayout.bottomControlsRowGap +
              16,
        ),
      );
    });
  });

  group('ReaderImagePipelineController', () {
    testWidgets(
      'getImageProvider publishes provider cache only after precache finishes',
      (tester) async {
        final runtimeState = ReaderRuntimeState()..applyImages(['image-url']);
        final pipelineState = ReaderImagePipelineState();
        final diagnosticsState = ReaderDiagnosticsState();
        final zoomController = TransformationController();
        final precacheCompleter = Completer<void>();
        var updateCount = 0;
        late ReaderImagePipelineController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                controller = ReaderImagePipelineController(
                  sourceService: sl<HazukiSourceService>(),
                  runtimeState: runtimeState,
                  pipelineState: pipelineState,
                  diagnosticsState: diagnosticsState,
                  zoomController: zoomController,
                  context: () => context,
                  isMounted: () => true,
                  updateState: (update) {
                    updateCount++;
                    update();
                  },
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
                        return MemoryImage(validPngBytes);
                      },
                  precacheImageCallback: (_) => precacheCompleter.future,
                );

                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final providerFuture = controller.getImageProvider('image-url');
        await tester.pump();

        expect(pipelineState.providerCache, isEmpty);
        expect(controller.cachedProviderFor('image-url'), isNull);

        precacheCompleter.complete();
        await providerFuture;
        await tester.pump();

        expect(pipelineState.providerCache.keys, ['image-url']);
        expect(controller.cachedProviderFor('image-url'), isNotNull);
        expect(updateCount, 1);
      },
    );

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
                  sourceService: sl<HazukiSourceService>(),
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
