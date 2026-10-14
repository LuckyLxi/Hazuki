import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/state/reader_image_content_state.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_settings_state.dart';
import 'package:hazuki/features/reader/state/reader_zoom_state.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/support/reader_display_session.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_settings_controller.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/reading/reader_filter_color.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SettingsState extends Fake implements ReaderSettingsState {
  _SettingsState(this.events);

  final List<String> events;
  @override
  int currentPageIndex = 1;
  @override
  int imageCount = 6;
  @override
  ReaderMode readerMode = ReaderMode.rightToLeft;
  @override
  bool doublePageMode = true;
  @override
  bool pinchToZoom = true;
  @override
  final ValueNotifier<int> pageIndexNotifier = ValueNotifier<int>(2);
  @override
  int spreadStartIndex(int spreadIndex) =>
      spreadIndex * (doublePageMode ? 2 : 1);

  @override
  void updateSettings({
    ReaderMode? readerMode,
    bool? doublePageMode,
    bool? tapToTurnPage,
    bool? volumeButtonTurnPage,
    bool? immersiveMode,
    bool? keepScreenOn,
    bool? customBrightness,
    double? brightnessValue,
    bool? filterEnabled,
    ReaderFilterColor? filterColor,
    double? filterStrength,
    bool? pageIndicator,
    bool? pinchToZoom,
    bool? longPressToSave,
  }) {
    events.add('state');
    if (readerMode != null) this.readerMode = readerMode;
    if (doublePageMode != null) this.doublePageMode = doublePageMode;
    if (pinchToZoom != null) this.pinchToZoom = pinchToZoom;
  }
}

// These tests do not invoke platform display effects. Unexpected calls fail.
class _DisplaySession extends Fake implements ReaderDisplaySession {}

class _ZoomState extends Fake implements ReaderZoomState {
  @override
  bool pinchToZoom = true;
  @override
  bool isZoomed = false;
  @override
  bool zoomInteracting = false;
  @override
  int activePointerCount = 0;
  @override
  void pointerDown() => activePointerCount++;
  @override
  void pointerUp() => activePointerCount--;
  @override
  void setZoomed(bool zoomed) => isZoomed = zoomed;
  @override
  void beginZoomInteraction() => zoomInteracting = true;
  @override
  void finishZoomInteraction({required bool zoomed}) {
    isZoomed = zoomed;
    zoomInteracting = activePointerCount > 1;
  }

  @override
  void resetZoom({bool resetPointers = true}) {
    isZoomed = false;
    zoomInteracting = false;
    if (resetPointers) activePointerCount = 0;
  }
}

class _ImageState extends Fake implements ReaderImageContentState {
  _ImageState(this.events);

  final List<String> events;
  void Function(List<String>)? beforeApply;
  String? error;
  @override
  List<String> images = const ['old'];
  @override
  void applyImages(List<String> nextImages) {
    beforeApply?.call(nextImages);
    images = List.unmodifiable(nextImages);
    events.add('images');
  }

  @override
  void markLoadImagesFailed(String message) {
    error = message;
    events.add('error');
  }
}

class _Source extends Mock implements SourceReaderGateway {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('settings state and callbacks', () {
    late List<String> events;
    late _SettingsState state;
    late SharedPreferences prefs;
    late Completer<void> pinchSync;
    late ReaderSettingsController settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      events = [];
      state = _SettingsState(events);
      pinchSync = Completer<void>();
      addTearDown(state.pageIndexNotifier.dispose);
      settings = ReaderSettingsController(
        runtimeState: state,
        settingsStore: const ReaderSettingsStore(),
        displaySession: _DisplaySession(),
        syncPositionToImageIndex: (index, {required trigger}) {
          expect(
            prefs.getString(ReaderSettingsStore.readingModeKey),
            state.readerMode.prefsValue,
          );
          events.add('position:$index:$trigger');
        },
        syncPositionAfterPinchToggle: (index) {
          expect(
            prefs.getBool(ReaderSettingsStore.pinchToZoomKey),
            state.pinchToZoom,
          );
          events.add('pinch:$index');
          return pinchSync.future;
        },
        resetZoomImmediately: ({reason = 'unspecified'}) =>
            events.add('zoom:$reason'),
        updateState: (update) => update(),
        logEvent: (_, {level = 'info', source = 'reader_ui', content}) =>
            events.add('log'),
        logPayload: ([extra]) => extra ?? {},
      );
    });

    test('mode change retains the image anchor and effect order', () async {
      await settings.updateReaderMode(ReaderMode.topToBottom);
      expect(state.readerMode, ReaderMode.topToBottom);
      expect(events, [
        'state',
        'log',
        'zoom:reading_mode_changed',
        'position:2:mode_changed_sync',
      ]);
    });

    test('double page change anchors using the previous spread size', () async {
      await prefs.setString(
        ReaderSettingsStore.readingModeKey,
        state.readerMode.prefsValue,
      );
      await settings.toggleDoublePageMode(false);
      expect(state.doublePageMode, isFalse);
      expect(prefs.getBool(ReaderSettingsStore.doublePageModeKey), isFalse);
      expect(events, [
        'state',
        'log',
        'zoom:double_page_mode_changed',
        'position:2:double_page_mode_changed_sync',
      ]);
    });

    test(
      'null mode and reselected mode do not reset zoom or navigate',
      () async {
        await settings.updateReaderMode(null);
        expect(events, isEmpty);
        await settings.updateReaderMode(state.readerMode);
        expect(events, ['state', 'log']);
      },
    );

    test(
      'disabling pinch uses the visible page and does not await navigation',
      () async {
        await settings.togglePinchToZoom(false);
        expect(events, [
          'zoom:pinch_to_zoom_disabled',
          'state',
          'log',
          'pinch:4',
        ]);
        expect(pinchSync.isCompleted, isFalse);
        pinchSync.complete();
      },
    );

    test('empty chapter uses a zero anchor when toggling pinch', () async {
      state.imageCount = 0;
      await settings.togglePinchToZoom(false);
      expect(events.last, 'pinch:0');
      pinchSync.complete();
    });
  });

  group('zoom state contract', () {
    testWidgets('tracks gestures and resets without a full runtime state', (
      tester,
    ) async {
      final state = _ZoomState();
      final transform = TransformationController(
        Matrix4.diagonal3Values(2, 2, 1),
      );
      final animation = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 280),
      );
      addTearDown(transform.dispose);
      addTearDown(animation.dispose);
      final zoom = ReaderZoomController(
        runtimeState: state,
        transformationController: transform,
        resetAnimController: animation,
        isMounted: () => true,
        updateState: (update) => update(),
        logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
        logPayload: ([extra]) => extra ?? {},
      );
      zoom.handlePointerDown(const PointerDownEvent(pointer: 1));
      zoom.handlePointerDown(const PointerDownEvent(pointer: 2));
      zoom.handleInteractionEnd(ScaleEndDetails());
      expect(state.isZoomed, isTrue);
      expect(state.zoomInteracting, isTrue);
      zoom.handlePointerEnd(const PointerUpEvent(pointer: 1));
      expect(state.zoomInteracting, isFalse);
      expect(state.activePointerCount, 1);
      zoom.resetZoomImmediately(reason: 'test');
      expect(state.activePointerCount, 0);
      expect(state.isZoomed, isFalse);
      expect(transform.value.getMaxScaleOnAxis(), 1);
    });

    testWidgets('unmounted interaction updates state without rebuilding', (
      tester,
    ) async {
      final state = _ZoomState();
      final transform = TransformationController(
        Matrix4.diagonal3Values(2, 2, 1),
      );
      final animation = AnimationController(vsync: tester);
      addTearDown(transform.dispose);
      addTearDown(animation.dispose);
      final zoom = ReaderZoomController(
        runtimeState: state,
        transformationController: transform,
        resetAnimController: animation,
        isMounted: () => false,
        updateState: (_) => fail('Unmounted zoom must not rebuild'),
        logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
        logPayload: ([extra]) => extra ?? {},
      );
      zoom.handleInteractionStart(ScaleStartDetails());
      zoom.handleInteractionUpdate(ScaleUpdateDetails());
      zoom.handleInteractionEnd(ScaleEndDetails());
      expect(state.isZoomed, isTrue);
      expect(state.zoomInteracting, isFalse);
    });
  });

  group('image content state contract', () {
    late List<String> events;
    late _ImageState state;
    late ReaderImagePipelineState pipeline;
    late TransformationController transform;
    late Completer<List<String>> incoming;
    late ReaderImagePipelineController controller;
    var mounted = true;

    setUp(() {
      events = [];
      state = _ImageState(events);
      pipeline = ReaderImagePipelineState()
        ..providerCache['old'] = const AssetImage('old');
      transform = TransformationController(Matrix4.diagonal3Values(2, 2, 1));
      incoming = Completer<List<String>>();
      mounted = true;
      final source = _Source();
      when(
        () => source.loadChapterImages(
          comicId: 'comic',
          epId: 'chapter',
          sourceKey: 'jm',
        ),
      ).thenAnswer((_) => incoming.future);
      controller = ReaderImagePipelineController(
        runtimeState: state,
        pipelineState: pipeline,
        diagnosticsState: ReaderDiagnosticsState(),
        zoomController: transform,
        context: () =>
            throw StateError('No view context needed for chapter load'),
        isMounted: () => mounted,
        updateState: (update) {
          events.add('update');
          update();
        },
        logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
        logPayload: ([extra]) => extra ?? {},
        logVisiblePageChange: ({required index, required trigger}) =>
            events.add('visible:$index'),
        noImageModeEnabled: () => true,
        comicId: 'comic',
        epId: 'chapter',
        sourceKey: 'jm',
        loadImagesErrorBuilder: (error) => 'failed:$error',
        sourceService: source,
      );
      addTearDown(controller.dispose);
      addTearDown(transform.dispose);
    });

    for (final images in <List<String>>[
      ['a', '', '  ', 'b'],
      [],
    ]) {
      test(
        'loads and sanitizes chapter images through its narrow state: $images',
        () async {
          state.beforeApply = (nextImages) {
            expect(pipeline.providerCache, isEmpty);
            expect(pipeline.imageIndexMap.keys.toList(), nextImages);
            expect(transform.value.getMaxScaleOnAxis(), 1);
          };
          final pending = controller.loadChapterImages();
          incoming.complete(images);
          await pending;
          expect(
            state.images,
            images.where((image) => image.trim().isNotEmpty).toList(),
          );
          expect(events, ['update', 'images', 'visible:0']);
        },
      );
    }

    test('chapter failure is applied through the error transition', () async {
      final pending = controller.loadChapterImages();
      incoming.completeError(StateError('source failure'));
      await pending;
      expect(state.error, contains('source failure'));
      expect(state.images, ['old']);
      expect(events, ['update', 'error']);
    });

    for (final fails in [false, true]) {
      test(
        'late chapter completion after unmount does not mutate state: $fails',
        () async {
          final pending = controller.loadChapterImages();
          mounted = false;
          if (fails) {
            incoming.completeError(StateError('late source failure'));
          } else {
            incoming.complete(['late']);
          }
          await pending;
          expect(state.images, ['old']);
          expect(state.error, isNull);
          expect(events, isEmpty);
          expect(pipeline.providerCache, contains('old'));
        },
      );
    }
  });
}
