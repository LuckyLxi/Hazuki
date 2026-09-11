import 'package:hazuki/features/reader/state/reader_scroll_state.dart';
import 'package:hazuki/features/reader/support/reader_input_controller.dart';
import 'package:hazuki/features/reader/support/reader_display_session.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:hazuki/features/reader/support/reader_view_bindings.dart';
import 'dart:async';
import 'package:hazuki/app/service_locator.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_controller.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/shared/reading/reader_filter_color.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/support/reader_page_context.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/features/reader/support/reader_settings_controller.dart';
import 'package:hazuki/shared/reading/reader_source_image_quality_settings.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';
import 'package:hazuki/features/settings/state/reading_settings_controller.dart';
import 'package:hazuki/features/reader/view/reader_overlay_layout.dart';
import 'package:hazuki/features/reader/view/reader_overlay_builders.dart';
import 'package:hazuki/widgets/reader_settings_content.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
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

  test('Windows shortcuts guide seen state persists', () async {
    SharedPreferences.setMockInitialValues({});
    const store = ReaderSettingsStore();

    expect(await store.hasSeenWindowsShortcutsGuide(), isFalse);
    await store.markWindowsShortcutsGuideSeen();
    expect(await store.hasSeenWindowsShortcutsGuide(), isTrue);
  });

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
          filterEnabled: true,
          filterColor: ReaderFilterColor.black,
          filterStrength: 0.6,
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
      expect(state.filterEnabled, isTrue);
      expect(state.filterColor, ReaderFilterColor.black);
      expect(state.filterStrength, 0.6);
      expect(state.pageIndicator, isTrue);
      expect(state.pinchToZoom, isTrue);
      expect(state.longPressToSave, isTrue);
      expect(state.readerSpreadSize, 2);
      expect(state.readerSpreadCount, 2);
      expect(state.itemKeys, hasLength(2));
    });

    test('applyImages resets transient session state', () {
      final state = ReaderRuntimeState()
        ..applyImages(['old-a', 'old-b', 'old-c'])
        ..setCurrentPageIndex(2)
        ..setControlsVisible(true)
        ..updateSliderDrag(2)
        ..recordSliderHaptic(2, DateTime(2026))
        ..markLoadImagesFailed('boom')
        ..setZoomed(true)
        ..beginZoomInteraction()
        ..pointerDown()
        ..pointerDown()
        ..pointerDown();

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
      expect(state.lastSliderHapticAt, isNull);
      expect(state.pageIndexNotifier.value, 0);
      expect(state.itemKeys, hasLength(3));
    });

    test('reader slider haptics are throttled and page-count aware', () {
      final state = ReaderRuntimeState()
        ..applyImages(List<String>.generate(300, (index) => 'img$index'));
      var hapticCount = 0;
      final base = DateTime(2026);

      expect(readerSliderHapticPageStep(40), 1);
      expect(readerSliderHapticPageStep(120), 2);
      expect(readerSliderHapticPageStep(300), 5);
      expect(readerSliderHapticPageStep(800), 10);

      maybeTriggerReaderSliderHaptic(
        runtimeState: state,
        value: 0,
        now: base,
        triggerHaptic: () => hapticCount++,
      );
      maybeTriggerReaderSliderHaptic(
        runtimeState: state,
        value: 3,
        now: base.add(const Duration(milliseconds: 100)),
        triggerHaptic: () => hapticCount++,
      );
      maybeTriggerReaderSliderHaptic(
        runtimeState: state,
        value: 5,
        now: base.add(const Duration(milliseconds: 120)),
        triggerHaptic: () => hapticCount++,
      );
      maybeTriggerReaderSliderHaptic(
        runtimeState: state,
        value: 10,
        now: base.add(const Duration(milliseconds: 160)),
        triggerHaptic: () => hapticCount++,
      );
      maybeTriggerReaderSliderHaptic(
        runtimeState: state,
        value: 10,
        force: true,
        now: base.add(const Duration(milliseconds: 161)),
        triggerHaptic: () => hapticCount++,
      );

      expect(hapticCount, 3);
      expect(state.lastSliderHapticPageIndex, 10);
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
          ..setCurrentPageIndex(1);
        runtimeState.setCurrentPageIndex(1);
        final scrollState = ReaderScrollState();
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
        addTearDown(runtimeState.dispose);

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
          scrollState: scrollState,
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
          onPageTargetChanged: (_) {},
          toggleControlsVisibility: () {},
        );
        final displayBridge = ReaderDisplayBridge(
          onVolumeButtonPressed: (_) async {},
        );
        final displaySession = ReaderDisplaySession(
          controller: ReaderDisplayBridge.controller,
          sessionId: displayBridge.sessionId,
          readSettings: () => runtimeState.settings,
        );
        final controller = ReaderSettingsController(
          runtimeState: runtimeState,
          settingsStore: settingsStore,
          navigationController: navigationController,
          displaySession: displaySession,
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

        await controller.toggleFilter(true);
        await controller.updateFilterColor(ReaderFilterColor.black);
        await controller.updateFilterStrength(0.7);

        expect(runtimeState.filterEnabled, isTrue);
        expect(runtimeState.filterColor, ReaderFilterColor.black);
        expect(runtimeState.filterStrength, 0.7);
        expect(prefs.getBool(ReaderSettingsStore.filterEnabledKey), isTrue);
        expect(
          prefs.getString(ReaderSettingsStore.filterColorKey),
          ReaderFilterColor.black.prefsValue,
        );
        expect(prefs.getDouble(ReaderSettingsStore.filterStrengthKey), 0.7);
        expect(logEvents, contains('Reader filter toggled'));
        expect(logEvents, contains('Reader filter color changed'));
      },
    );
  });

  group('ReaderSessionController', () {
    testWidgets('offline session never loads an empty chapter from source', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const SizedBox.shrink());
      final runtimeState = ReaderRuntimeState();
      final scrollController = ScrollController();
      final pageController = PageController();
      final focusNode = FocusNode();
      final transformationController = TransformationController();
      var appliedInitialImages = false;
      var loadChapterImagesCount = 0;
      final displayBridge = ReaderDisplayBridge(
        onVolumeButtonPressed: (_) async {},
      );
      final displaySession = ReaderDisplaySession(
        controller: ReaderDisplayBridge.controller,
        sessionId: displayBridge.sessionId,
        readSettings: () => runtimeState.settings,
      );
      final sessionController = ReaderSessionController(
        viewBindings: ReaderViewBindings(
          scrollController: scrollController,
          pageController: pageController,
          focusNode: focusNode,
          zoomController: transformationController,
          onNoImageModeChanged: () {},
          onScrollPositionChanged: () {},
          onZoomChanged: () {},
          noImageMode: hazukiNoImageModeNotifier,
        ),
        runtimeState: runtimeState,
        displayBridge: displayBridge,
        displaySession: displaySession,
        settingsStore: const ReaderSettingsStore(),
        applyInitialImages: (images, {required trigger}) {
          appliedInitialImages = true;
          expect(images, isEmpty);
          expect(trigger, 'offline_constructor_images');
        },
        loadChapterImages: ({trigger = 'manual'}) async {
          loadChapterImagesCount++;
        },
        isMounted: () => false,
        updateState: (update) => update(),
        logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
        logPayload: ([extra]) => extra ?? <String, dynamic>{},
        comicId: 'comic',
        epId: 'ep',
        chapterTitle: 'Chapter 1',
        chapterIndex: 0,
        widgetImages: const [],
        readingProgressService: sl<ReadingProgressService>(),
        offlineMode: true,
      );

      sessionController.initialize();

      expect(appliedInitialImages, isTrue);
      expect(loadChapterImagesCount, 0);

      sessionController.dispose();
    });

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

    testWidgets('does not reapply immersive mode after the reader closes', (
      tester,
    ) async {
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
      final displayBridge = ReaderDisplayBridge(
        onVolumeButtonPressed: (_) async {},
      );
      final displaySession = ReaderDisplaySession(
        controller: ReaderDisplayBridge.controller,
        sessionId: displayBridge.sessionId,
        readSettings: () => runtimeState.settings,
      );
      final sessionController = ReaderSessionController(
        viewBindings: ReaderViewBindings(
          scrollController: scrollController,
          pageController: pageController,
          focusNode: focusNode,
          zoomController: transformationController,
          onNoImageModeChanged: () {},
          onScrollPositionChanged: () {},
          onZoomChanged: () {},
          noImageMode: hazukiNoImageModeNotifier,
        ),
        runtimeState: runtimeState,
        displayBridge: displayBridge,
        displaySession: displaySession,
        settingsStore: const ReaderSettingsStore(),
        applyInitialImages: (_, {required trigger}) {},
        loadChapterImages: ({trigger = 'manual'}) async {},
        isMounted: () => true,
        updateState: (update) => update(),
        logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
        logPayload: ([extra]) => extra ?? <String, dynamic>{},
        comicId: 'comic',
        epId: 'ep',
        chapterTitle: 'Chapter 1',
        chapterIndex: 0,
        widgetImages: const [],
        readingProgressService: sl<ReadingProgressService>(),
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
      expect(immersiveModeCalls, isEmpty);
      expect(
        overlayRestoreCalls.last.arguments,
        containsAll(['SystemUiOverlay.top', 'SystemUiOverlay.bottom']),
      );
    });
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
        sourceService: sl<SourceSettingsGateway>(),
      );
      addTearDown(controller.dispose);

      await controller.loadSettings();
      expect(controller.filterEnabled, isFalse);
      expect(controller.filterColor, ReaderFilterColor.yellow);
      expect(controller.filterStrength, 0.3);
      await controller.updateReaderMode(ReaderMode.rightToLeft);
      await controller.toggleDoublePageMode(true);
      await controller.toggleTapToTurnPage(true);
      await controller.toggleVolumeButtonTurnPage(true);
      await controller.toggleImmersiveMode(false);
      await controller.toggleKeepScreenOn(false);
      await controller.toggleCustomBrightness(true);
      await controller.updateBrightness(1.4);
      await controller.toggleFilter(true);
      await controller.updateFilterColor(ReaderFilterColor.black);
      await controller.updateFilterStrength(1.4);
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
      expect(prefs.getBool(ReaderSettingsStore.filterEnabledKey), isTrue);
      expect(
        prefs.getString(ReaderSettingsStore.filterColorKey),
        ReaderFilterColor.black.prefsValue,
      );
      expect(prefs.getDouble(ReaderSettingsStore.filterStrengthKey), 1.0);
      expect(prefs.getBool(ReaderSettingsStore.pageIndicatorKey), isTrue);
      expect(prefs.getBool(ReaderSettingsStore.pinchToZoomKey), isTrue);
      expect(prefs.getBool(ReaderSettingsStore.longPressToSaveKey), isTrue);
    });
  });

  group('ReaderSettingsContent', () {
    testWidgets('settings sliders fill their height and center their labels', (
      tester,
    ) async {
      ReaderFilterColor? selectedColor;
      ReaderMode? selectedMode;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ReaderSettingsContent(
              surface: ReaderSettingsSurface.page,
              readerMode: ReaderMode.topToBottom,
              doublePageMode: false,
              tapToTurnPage: false,
              volumeButtonTurnPage: false,
              pinchToZoom: false,
              longPressToSave: false,
              immersiveMode: true,
              keepScreenOn: true,
              pageIndicator: false,
              customBrightness: false,
              brightnessValue: 0.5,
              filterEnabled: true,
              filterColor: ReaderFilterColor.yellow,
              filterStrength: 0.3,
              sourceImageQuality: ReaderSourceImageQualitySnapshot.defaults,
              onReaderModeChanged: (value) => selectedMode = value,
              onDoublePageModeChanged: (_) {},
              onTapToTurnPageChanged: (_) {},
              onVolumeButtonTurnPageChanged: (_) {},
              onPinchToZoomChanged: (_) {},
              onLongPressToSaveChanged: (_) {},
              onImmersiveModeChanged: (_) {},
              onKeepScreenOnChanged: (_) {},
              onPageIndicatorChanged: (_) {},
              onCustomBrightnessChanged: (_) {},
              onBrightnessChanged: (_) {},
              onFilterEnabledChanged: (_) {},
              onFilterColorChanged: (value) => selectedColor = value,
              onFilterStrengthChanged: (_) {},
              onCopyMangaImageQualityChanged: (_) {},
              onPicacgImageQualityChanged: (_) {},
            ),
          ),
        ),
      );

      final modeSlider = find.byKey(
        const ValueKey<String>('reader-mode-slider'),
      );
      final modeSliderRect = tester.getRect(modeSlider);
      final horizontalLabelRect = tester.getRect(
        find.text('Horizontal paging'),
      );
      expect(
        horizontalLabelRect.center.dy,
        closeTo(modeSliderRect.center.dy, 1),
      );

      await tester.tapAt(
        Offset(
          modeSliderRect.center.dx + modeSliderRect.width / 4,
          modeSliderRect.bottom - 2,
        ),
      );
      expect(selectedMode, ReaderMode.rightToLeft);

      final slider = find.byKey(
        const ValueKey<String>('reader-filter-color-slider'),
      );
      await tester.scrollUntilVisible(slider, 200);
      await tester.pumpAndSettle();

      final sliderRect = tester.getRect(slider);
      final blackLabelRect = tester.getRect(find.text('Black'));
      expect(blackLabelRect.center.dy, closeTo(sliderRect.center.dy, 1));

      await tester.tapAt(
        Offset(
          sliderRect.center.dx + sliderRect.width / 4,
          sliderRect.bottom - 2,
        ),
      );
      expect(selectedColor, ReaderFilterColor.black);
    });
  });

  group('ReaderPageContext', () {
    test('copyForChapter preserves callbacks and offline chapter data', () {
      Future<void> onFavorite(BuildContext context) async {}
      Widget commentsBuilder({
        required String comicId,
        String? subId,
        String? chapterId,
        required String sourceKey,
        ScrollController? scrollController,
        Future<void> Function()? onRequestTabFullscreen,
        CommentsInteractionState? interactionState,
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
        offlineMode: true,
        offlineChapters: const [
          ReaderOfflineChapterData(
            epId: 'ep-2',
            title: 'Chapter 2',
            index: 1,
            images: ['local-image-2'],
          ),
        ],
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
      expect(next.offlineMode, isTrue);
      expect(next.offlineChapters, hasLength(1));
      expect(next.comicTheme, same(theme));
      expect(next.onFavoriteRequested, same(onFavorite));
      expect(next.commentsWidgetBuilder, same(commentsBuilder));
      expect(next.epId, 'ep-2');
      expect(next.chapterTitle, 'Chapter 2');
      expect(next.chapterIndex, 1);
      expect(next.images, ['local-image-2']);
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
                  sourceService: sl<SourceReaderGateway>(),
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
                  sourceService: sl<SourceReaderGateway>(),
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

    testWidgets('prefetchAround schedules the visible page before neighbors', (
      tester,
    ) async {
      final runtimeState = ReaderRuntimeState()
        ..applyImages(['img0', 'img1', 'img2', 'img3', 'img4', 'img5']);
      final pipelineState = ReaderImagePipelineState();
      final diagnosticsState = ReaderDiagnosticsState();
      final zoomController = TransformationController();
      final requestedUrls = <String>[];
      late ReaderImagePipelineController controller;
      addTearDown(zoomController.dispose);
      addTearDown(runtimeState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller = ReaderImagePipelineController(
                sourceService: sl<SourceReaderGateway>(),
                runtimeState: runtimeState,
                pipelineState: pipelineState,
                diagnosticsState: diagnosticsState,
                zoomController: zoomController,
                context: () => context,
                isMounted: () => true,
                updateState: (update) => update(),
                logEvent:
                    (title, {level = 'info', source = 'reader_ui', content}) {},
                logPayload: ([extra]) => extra ?? <String, dynamic>{},
                logVisiblePageChange: ({required index, required trigger}) {},
                noImageModeEnabled: () => false,
                comicId: 'comic',
                epId: 'ep',
                loadImagesErrorBuilder: (error) => '$error',
                imageProviderBuilder: (url, {bool useDiskCache = true}) async {
                  requestedUrls.add(url);
                  return MemoryImage(validPngBytes);
                },
                precacheImageCallback: (_) async {},
              );

              return const SizedBox.shrink();
            },
          ),
        ),
      );

      controller.prefetchAround(3);
      await tester.pump();

      expect(requestedUrls.first, 'img3');
    });

    testWidgets('placeholder aspect ratio stays stable until image resolves', (
      tester,
    ) async {
      final runtimeState = ReaderRuntimeState()
        ..applyImages(['img0', 'img1', 'img2']);
      final pipelineState = ReaderImagePipelineState()
        ..imageAspectRatioCache['img0'] = 0.6;
      final diagnosticsState = ReaderDiagnosticsState();
      final zoomController = TransformationController();
      late ReaderImagePipelineController controller;
      addTearDown(zoomController.dispose);
      addTearDown(runtimeState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller = ReaderImagePipelineController(
                sourceService: sl<SourceReaderGateway>(),
                runtimeState: runtimeState,
                pipelineState: pipelineState,
                diagnosticsState: diagnosticsState,
                zoomController: zoomController,
                context: () => context,
                isMounted: () => true,
                updateState: (update) => update(),
                logEvent:
                    (title, {level = 'info', source = 'reader_ui', content}) {},
                logPayload: ([extra]) => extra ?? <String, dynamic>{},
                logVisiblePageChange: ({required index, required trigger}) {},
                noImageModeEnabled: () => false,
                comicId: 'comic',
                epId: 'ep',
                loadImagesErrorBuilder: (error) => '$error',
              );

              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(controller.resolvePlaceholderAspectRatio(1), 0.6);

      pipelineState.imageAspectRatioCache['img2'] = 1.1;

      expect(controller.resolvePlaceholderAspectRatio(1), 0.6);
      expect(pipelineState.listPlaceholderAspectRatioCache['img1'], 0.6);
    });
  });

  group('ReaderNavigationController', () {
    test('arrow keys follow the active reader direction', () async {
      final state = ReaderRuntimeState()
        ..applyImages(['a', 'b', 'c'])
        ..updateSettings(readerMode: ReaderMode.topToBottom)
        ..setCurrentPageIndex(1);
      final scrollController = ScrollController();
      final pageController = PageController();
      final focusNode = FocusNode();
      addTearDown(scrollController.dispose);
      addTearDown(pageController.dispose);
      addTearDown(focusNode.dispose);
      addTearDown(state.dispose);
      final controller = ReaderNavigationController(
        runtimeState: state,
        diagnosticsState: ReaderDiagnosticsState(),
        scrollState: ReaderScrollState(),
        scrollController: scrollController,
        pageController: pageController,
        isMounted: () => true,
        updateState: (update) => update(),
        logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
        logPayload: ([extra]) => extra ?? <String, dynamic>{},
        logVisiblePageChange: ({required index, required trigger}) {},
        resetZoomImmediately: ({reason = 'unspecified'}) {},
        onPageTargetChanged: (_) {},
        toggleControlsVisibility: () {},
      );

      final input = ReaderInputController(
        readState: () => ReaderInputState(
          readerMode: state.readerMode,
          volumeButtonTurnPage: state.volumeButtonTurnPage,
          isWindows: true,
          isAltPressed: false,
          isControlPressed: false,
          activePointerCount: 0,
        ),
        previousPage: (trigger) => controller.goPreviousPage(trigger: trigger),
        nextPage: (trigger) => controller.goNextPage(trigger: trigger),
        jumpToAdjacentChapter: (_) async {},
        onScalingInputChanged: () {},
      );

      KeyDownEvent keyEvent(
        LogicalKeyboardKey logicalKey,
        PhysicalKeyboardKey physicalKey,
      ) {
        return KeyDownEvent(
          logicalKey: logicalKey,
          physicalKey: physicalKey,
          timeStamp: Duration.zero,
        );
      }

      expect(
        input.handleKeyEvent(
          focusNode,
          keyEvent(LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown),
        ),
        KeyEventResult.handled,
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.currentPageIndex, 2);

      input.handleKeyEvent(
        focusNode,
        keyEvent(LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp),
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.currentPageIndex, 1);
      expect(
        input.handleKeyEvent(
          focusNode,
          keyEvent(LogicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowLeft),
        ),
        KeyEventResult.handled,
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.currentPageIndex, 1);

      state.updateSettings(readerMode: ReaderMode.rightToLeft);
      input.handleKeyEvent(
        focusNode,
        keyEvent(LogicalKeyboardKey.arrowRight, PhysicalKeyboardKey.arrowRight),
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.currentPageIndex, 2);

      input.handleKeyEvent(
        focusNode,
        keyEvent(LogicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowLeft),
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.currentPageIndex, 1);
      expect(
        input.handleKeyEvent(
          focusNode,
          keyEvent(LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown),
        ),
        KeyEventResult.handled,
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.currentPageIndex, 1);
    });

    test(
      'center tap toggles controls and edge taps request page navigation',
      () async {
        final state = ReaderRuntimeState()
          ..applyImages(['a', 'b', 'c'])
          ..updateSettings(readerMode: ReaderMode.rightToLeft)
          ..updateSettings(tapToTurnPage: true)
          ..setCurrentPageIndex(1);
        state.setCurrentPageIndex(1);

        var toggled = 0;
        final controller = ReaderNavigationController(
          runtimeState: state,
          diagnosticsState: ReaderDiagnosticsState(),
          scrollState: ReaderScrollState(),
          scrollController: ScrollController(),
          pageController: PageController(),
          isMounted: () => true,
          updateState: (update) => update(),
          logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
          logPayload: ([extra]) => extra ?? <String, dynamic>{},
          logVisiblePageChange: ({required index, required trigger}) {},
          resetZoomImmediately: ({reason = 'unspecified'}) {},
          onPageTargetChanged: (_) {},
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

        state.setCurrentPageIndex(0);
        state.setCurrentPageIndex(0);
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

    test('goToPage immediately prefetches the requested target page', () async {
      final state = ReaderRuntimeState()..applyImages(['a', 'b', 'c', 'd']);
      final scrollController = ScrollController();
      final pageController = PageController();
      final prefetched = <int>[];
      final prefetchedAhead = <int>[];
      addTearDown(scrollController.dispose);
      addTearDown(pageController.dispose);
      addTearDown(state.dispose);
      final controller = ReaderNavigationController(
        runtimeState: state,
        diagnosticsState: ReaderDiagnosticsState(),
        scrollState: ReaderScrollState(),
        scrollController: scrollController,
        pageController: pageController,
        isMounted: () => true,
        updateState: (update) => update(),
        logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
        logPayload: ([extra]) => extra ?? <String, dynamic>{},
        logVisiblePageChange: ({required index, required trigger}) {},
        resetZoomImmediately: ({reason = 'unspecified'}) {},
        onPageTargetChanged: (index) {
          prefetched.add(index);
          prefetchedAhead.add(index);
        },
        toggleControlsVisibility: () {},
      );

      await controller.goToPage(3, trigger: 'bottom_slider');

      expect(state.currentPageIndex, 3);
      expect(state.pageIndexNotifier.value, 3);
      expect(prefetched, [3]);
      expect(prefetchedAhead, [3]);
    });

    testWidgets('top-to-bottom goToPage stabilizes the programmatic target', (
      tester,
    ) async {
      final state = ReaderRuntimeState()
        ..applyImages(List<String>.generate(30, (index) => 'img$index'))
        ..updateSettings(readerMode: ReaderMode.topToBottom);
      final scrollState = ReaderScrollState();
      final diagnosticsState = ReaderDiagnosticsState();
      final scrollController = ScrollController();
      final pageController = PageController();
      addTearDown(scrollController.dispose);
      addTearDown(pageController.dispose);
      addTearDown(state.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            height: 400,
            child: ListView.builder(
              controller: scrollController,
              itemCount: state.readerSpreadCount,
              itemBuilder: (context, index) {
                return SizedBox(
                  key: state.itemKeys[index],
                  height: 100,
                  child: Text('page $index'),
                );
              },
            ),
          ),
        ),
      );

      final controller = ReaderNavigationController(
        runtimeState: state,
        diagnosticsState: diagnosticsState,
        scrollState: scrollState,
        scrollController: scrollController,
        pageController: pageController,
        isMounted: () => true,
        updateState: (update) => update(),
        logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
        logPayload: ([extra]) => extra ?? <String, dynamic>{},
        logVisiblePageChange: ({required index, required trigger}) {},
        resetZoomImmediately: ({reason = 'unspecified'}) {},
        onPageTargetChanged: (_) {},
        toggleControlsVisibility: () {},
      );

      final navigation = controller.goToPage(12, trigger: 'bottom_slider');
      await tester.pumpAndSettle();
      await navigation;

      expect(scrollState.stabilizingProgrammaticListTargetIndex, 12);
      expect(scrollState.hasActiveProgrammaticListStabilization, isTrue);

      controller.handleScrollNotification(
        ScrollStartNotification(
          metrics: scrollController.position,
          context: tester.element(find.byType(ListView)),
          dragDetails: DragStartDetails(),
        ),
      );

      expect(scrollState.stabilizingProgrammaticListTargetIndex, isNull);
    });

    testWidgets(
      'top-to-bottom position sync stabilizes the programmatic target',
      (tester) async {
        final state = ReaderRuntimeState()
          ..applyImages(List<String>.generate(30, (index) => 'img$index'))
          ..updateSettings(readerMode: ReaderMode.topToBottom);
        final scrollState = ReaderScrollState();
        final diagnosticsState = ReaderDiagnosticsState();
        final scrollController = ScrollController();
        final pageController = PageController();
        addTearDown(scrollController.dispose);
        addTearDown(pageController.dispose);
        addTearDown(state.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              height: 400,
              child: ListView.builder(
                controller: scrollController,
                itemCount: state.readerSpreadCount,
                itemBuilder: (context, index) {
                  return SizedBox(
                    key: state.itemKeys[index],
                    height: 100,
                    child: Text('page $index'),
                  );
                },
              ),
            ),
          ),
        );

        final controller = ReaderNavigationController(
          runtimeState: state,
          diagnosticsState: diagnosticsState,
          scrollState: scrollState,
          scrollController: scrollController,
          pageController: pageController,
          isMounted: () => true,
          updateState: (update) => update(),
          logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
          logPayload: ([extra]) => extra ?? <String, dynamic>{},
          logVisiblePageChange: ({required index, required trigger}) {},
          resetZoomImmediately: ({reason = 'unspecified'}) {},
          onPageTargetChanged: (_) {},
          toggleControlsVisibility: () {},
        );

        controller.syncPositionToImageIndex(12, trigger: 'mode_changed_sync');
        expect(scrollState.activeProgrammaticListTargetIndex, 12);
        await tester.pumpAndSettle();

        expect(scrollState.stabilizingProgrammaticListTargetIndex, 12);
        expect(scrollState.hasActiveProgrammaticListStabilization, isTrue);
      },
    );

    testWidgets(
      'top-to-bottom stabilization compensates upstream height changes',
      (tester) async {
        final state = ReaderRuntimeState()
          ..applyImages(List<String>.generate(30, (index) => 'img$index'))
          ..updateSettings(readerMode: ReaderMode.topToBottom);
        final scrollState = ReaderScrollState();
        final diagnosticsState = ReaderDiagnosticsState();
        final scrollController = ScrollController();
        final pageController = PageController();
        addTearDown(scrollController.dispose);
        addTearDown(pageController.dispose);
        addTearDown(state.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              height: 400,
              child: ListView.builder(
                controller: scrollController,
                scrollCacheExtent: ScrollCacheExtent.pixels(1000),
                itemCount: state.readerSpreadCount,
                itemBuilder: (context, index) {
                  return SizedBox(
                    key: state.itemKeys[index],
                    height: 100,
                    child: Text('page $index'),
                  );
                },
              ),
            ),
          ),
        );

        final controller = ReaderNavigationController(
          runtimeState: state,
          diagnosticsState: diagnosticsState,
          scrollState: scrollState,
          scrollController: scrollController,
          pageController: pageController,
          isMounted: () => true,
          updateState: (update) => update(),
          logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
          logPayload: ([extra]) => extra ?? <String, dynamic>{},
          logVisiblePageChange: ({required index, required trigger}) {},
          resetZoomImmediately: ({reason = 'unspecified'}) {},
          onPageTargetChanged: (_) {},
          toggleControlsVisibility: () {},
        );

        scrollController.jumpTo(100);
        scrollState.markProgrammaticListScrollCompleted(5, stabilize: true);
        await tester.pump();

        final beforeCorrection = scrollController.position.pixels;
        controller.handleListImageAspectRatioResolved(
          imageIndex: 1,
          previousAspectRatio: 1,
          resolvedAspectRatio: 0.5,
        );
        await tester.pump();

        expect(scrollController.position.pixels, greaterThan(beforeCorrection));
      },
    );
  });

  group('ReaderDiagnosticsController', () {
    test('creates a snapshot from reader runtime and pipeline state', () {
      final runtimeState = ReaderRuntimeState()
        ..applyImages(['a', 'b', 'c'])
        ..setCurrentPageIndex(1)
        ..setControlsVisible(true)
        ..setZoomed(true);
      runtimeState.setCurrentPageIndex(1);
      final pipelineState = ReaderImagePipelineState()
        ..activeUnscrambleTasks = 2
        ..prefetchAheadRunning = true;
      final scrollState = ReaderScrollState();
      final diagnosticsState = ReaderDiagnosticsState();
      scrollState.lastObservedListPixels = 12.345;
      final scrollController = ScrollController();
      final pageController = PageController();
      final zoomController = TransformationController();
      addTearDown(scrollController.dispose);
      addTearDown(pageController.dispose);
      addTearDown(zoomController.dispose);
      addTearDown(pipelineState.dispose);
      addTearDown(runtimeState.dispose);

      final controller = ReaderDiagnosticsController(
        runtimeState: runtimeState,
        imagePipelineState: pipelineState,
        diagnosticsState: diagnosticsState,
        scrollState: scrollState,
        scrollController: scrollController,
        pageController: pageController,
        zoomController: zoomController,
        sessionId: () => 'session-1',
        noImageModeEnabled: () => true,
        log: (_, {level = 'info', source = 'reader_ui', content}) {},
        comicId: 'comic-1',
        epId: 'ep-1',
        chapterTitle: 'Chapter 1',
        chapterIndex: 0,
      );

      final snapshot = controller.createSnapshot();

      expect(snapshot.readerSessionId, 'session-1');
      expect(snapshot.comicId, 'comic-1');
      expect(snapshot.currentPageIndex, 1);
      expect(snapshot.currentPage, 2);
      expect(snapshot.totalPages, 3);
      expect(snapshot.controlsVisible, isTrue);
      expect(snapshot.noImageModeEnabled, isTrue);
      expect(snapshot.isZoomed, isTrue);
      expect(snapshot.activeUnscrambleTasks, 2);
      expect(snapshot.prefetchAheadRunning, isTrue);
      expect(snapshot.lastObservedListPixels, 12.35);
      expect(snapshot.listSnapshot, isNull);
      expect(snapshot.pageControllerPage, isNull);
    });

    test('normalizes and deduplicates visible page logs', () {
      final runtimeState = ReaderRuntimeState()
        ..applyImages(['a', 'b', 'c', 'd'])
        ..updateSettings(readerMode: ReaderMode.topToBottom);
      final pipelineState = ReaderImagePipelineState();
      final scrollState = ReaderScrollState();
      final diagnosticsState = ReaderDiagnosticsState();
      final scrollController = ScrollController();
      final pageController = PageController();
      final zoomController = TransformationController();
      final logs = <Map<String, Object?>>[];
      addTearDown(scrollController.dispose);
      addTearDown(pageController.dispose);
      addTearDown(zoomController.dispose);
      addTearDown(pipelineState.dispose);
      addTearDown(runtimeState.dispose);

      final controller = ReaderDiagnosticsController(
        runtimeState: runtimeState,
        imagePipelineState: pipelineState,
        diagnosticsState: diagnosticsState,
        scrollState: scrollState,
        scrollController: scrollController,
        pageController: pageController,
        zoomController: zoomController,
        sessionId: () => 'session-1',
        noImageModeEnabled: () => false,
        log: (title, {level = 'info', source = 'reader_ui', content}) {
          logs.add({
            'title': title,
            'level': level,
            'source': source,
            'content': content,
          });
        },
        comicId: 'comic-1',
        epId: 'ep-1',
        chapterTitle: 'Chapter 1',
        chapterIndex: 0,
      );

      controller.logVisiblePageChange(index: 99, trigger: 'test');
      controller.logVisiblePageChange(index: 3, trigger: 'duplicate');

      expect(logs, hasLength(1));
      expect(logs.single['title'], 'Reader visible page changed');
      expect(logs.single['source'], 'reader_position');
      final content = logs.single['content']! as Map<String, dynamic>;
      expect(content['trigger'], 'test');
      expect(content['pageIndex'], 3);
      expect(content['page'], 4);
      expect(content['visibleImageIndices'], [3]);
      expect(content['nearbyRenderedItems'], [
        {'index': 1, 'mounted': false},
        {'index': 2, 'mounted': false},
        {'index': 3, 'mounted': false},
      ]);
    });
  });
}
