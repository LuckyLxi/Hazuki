import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';

void main() {
  test('page observers see the complete reset when chapter images change', () {
    final state = ReaderRuntimeState()
      ..applyImages(['a', 'b', 'c'])
      ..setCurrentPageIndex(2)
      ..setControlsVisible(true)
      ..setZoomed(true)
      ..beginZoomInteraction()
      ..pointerDown()
      ..pointerDown()
      ..updateSliderDrag(2)
      ..recordSliderHaptic(2, DateTime(2026))
      ..markLoadImagesFailed('old error');
    addTearDown(state.dispose);
    var notifications = 0;
    state.pageIndexNotifier.addListener(() {
      notifications++;
      expect(state.currentPageIndex, state.pageIndexNotifier.value);
      expect(state.images, ['new']);
      expect(state.itemKeys.length, 1);
      expect(state.loadingImages, isFalse);
      expect(state.loadImagesError, isNull);
      expect(state.isZoomed, isFalse);
      expect(state.zoomInteracting, isFalse);
      expect(state.activePointerCount, 0);
      expect(state.sliderDragging, isFalse);
      expect(state.sliderDragValue, 0);
      expect(state.lastSliderHapticAt, isNull);
      expect(state.lastSliderHapticPageIndex, isNull);
      expect(state.controlsVisible, isTrue);
    });
    state.applyImages(['new']);
    expect(notifications, 1);
  });

  test(
    'navigation normalizes both page indices with one notification per change',
    () {
      final state = ReaderRuntimeState()
        ..applyImages(['a', 'b', 'c', 'd', 'e'])
        ..updateSettings(doublePageMode: true);
      addTearDown(state.dispose);
      final seen = <int>[];
      state.pageIndexNotifier.addListener(() {
        expect(state.currentPageIndex, state.pageIndexNotifier.value);
        seen.add(state.currentPageIndex);
      });
      state.setCurrentPageIndex(99);
      expect(state.spreadImageIndices(state.currentPageIndex), [4]);
      state.setCurrentPageIndex(2);
      state.setCurrentPageIndex(-1);
      expect(seen, [2, 0]);
      state.applyImages([]);
      state.setCurrentPageIndex(10);
      expect(state.currentPageIndex, 0);
      expect(state.pageIndexNotifier.value, 0);
    },
  );

  test(
    'caller mutations cannot change images or the spread key collection',
    () {
      final incoming = ['a', 'b', 'c'];
      final state = ReaderRuntimeState()..applyImages(incoming);
      addTearDown(state.dispose);
      incoming.clear();
      expect(state.images.length, 3);
      expect(() => state.images.clear(), throwsUnsupportedError);
      expect(() => state.itemKeys.clear(), throwsUnsupportedError);
      final firstKey = state.itemKeys.first;
      state.updateSettings(keepScreenOn: !state.keepScreenOn);
      expect(state.itemKeys.first, same(firstKey));
      state.updateSettings(doublePageMode: true);
      expect(state.itemKeys.length, 2);
      expect(state.itemKeys.first, isNot(same(firstKey)));
    },
  );

  test(
    'settings updates preserve other preferences and previous snapshots',
    () {
      final state = ReaderRuntimeState()
        ..updateSettings(
          readerMode: ReaderMode.rightToLeft,
          brightnessValue: 0.7,
        );
      addTearDown(state.dispose);
      final saved = state.settings;
      state.updateSettings(doublePageMode: !saved.doublePageMode);
      expect(state.readerMode, saved.readerMode);
      expect(state.brightnessValue, 0.7);
      expect(state.settings.doublePageMode, !saved.doublePageMode);
      expect(saved.doublePageMode, isNot(state.doublePageMode));
      state.applySettingsSnapshot(saved);
      expect(state.settings, same(saved));
    },
  );

  testWidgets(
    'ending scale interaction keeps paging locked until fingers release',
    (tester) async {
      final state = ReaderRuntimeState()..updateSettings(pinchToZoom: true);
      final transform = TransformationController();
      final animation = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 280),
      );
      final zoom = _zoom(state, transform, animation);
      addTearDown(state.dispose);
      addTearDown(transform.dispose);
      addTearDown(animation.dispose);

      zoom.handlePointerDown(const PointerDownEvent(pointer: 1));
      zoom.handlePointerDown(const PointerDownEvent(pointer: 2));
      zoom.handleInteractionEnd(ScaleEndDetails());
      expect(state.zoomInteracting, isTrue);
      expect(state.pageNavigationLocked, isTrue);
      zoom.handlePointerEnd(const PointerUpEvent(pointer: 1));
      expect(state.zoomInteracting, isFalse);
      expect(state.pageNavigationLocked, isFalse);
      zoom.handlePointerEnd(const PointerUpEvent(pointer: 2));
      zoom.handlePointerEnd(const PointerUpEvent(pointer: 2));
      expect(state.activePointerCount, 0);
    },
  );

  testWidgets(
    'animated and immediate zoom resets retain their pointer semantics',
    (tester) async {
      final state = ReaderRuntimeState()
        ..updateSettings(pinchToZoom: true)
        ..pointerDown()
        ..pointerDown()
        ..beginZoomInteraction()
        ..setZoomed(true);
      final transform = TransformationController(
        Matrix4.diagonal3Values(1.8, 1.8, 1),
      );
      final animation = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 280),
      );
      final zoom = _zoom(state, transform, animation);
      addTearDown(state.dispose);
      addTearDown(transform.dispose);
      addTearDown(animation.dispose);

      zoom.resetZoom();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(transform.value.getMaxScaleOnAxis(), inExclusiveRange(1, 1.8));
      await tester.pump(const Duration(milliseconds: 140));
      await tester.pumpAndSettle();
      expect(transform.value.getMaxScaleOnAxis(), 1);
      expect(state.isZoomed, isFalse);
      expect(state.zoomInteracting, isFalse);
      expect(state.activePointerCount, 2);
      expect(state.pageNavigationLocked, isTrue);
      zoom.resetZoomImmediately();
      expect(state.activePointerCount, 0);
      expect(state.pageNavigationLocked, isFalse);
    },
  );
}

ReaderZoomController _zoom(
  ReaderRuntimeState state,
  TransformationController transform,
  AnimationController animation,
) => ReaderZoomController(
  runtimeState: state,
  transformationController: transform,
  resetAnimController: animation,
  isMounted: () => true,
  updateState: (update) => update(),
  logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
  logPayload: ([extra]) => extra ?? {},
);
