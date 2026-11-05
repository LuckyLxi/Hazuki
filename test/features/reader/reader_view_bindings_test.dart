import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/support/reader_view_bindings.dart';

class _Scroll extends ScrollController {
  bool disposed = false;
  void emit() => notifyListeners();
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _Focus extends FocusNode {
  int requests = 0;
  bool disposed = false;
  @override
  void requestFocus([FocusNode? node]) {
    requests++;
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _Zoom extends TransformationController {
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _Harness {
  final scroll = _Scroll();
  final focus = _Focus();
  final zoom = _Zoom();
  final noImages = ValueNotifier(false);
  int scrollEvents = 0;
  int zoomEvents = 0;
  int noImageEvents = 0;
  late final bindings = ReaderViewBindings(
    scrollController: scroll,
    focusNode: focus,
    zoomController: zoom,
    noImageMode: noImages,
    onScrollPositionChanged: () => scrollEvents++,
    onZoomChanged: () => zoomEvents++,
    onNoImageModeChanged: () => noImageEvents++,
  );

  void dispose() {
    bindings.dispose();
    scroll.dispose();
    focus.dispose();
    zoom.dispose();
    noImages.dispose();
  }
}

void main() {
  test(
    'attaches listeners once and detaches without disposing controllers',
    () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.bindings.attach();
      h.bindings.attach();
      h.scroll.emit();
      h.zoom.value = Matrix4.diagonal3Values(2, 2, 1);
      h.noImages.value = true;
      expect([h.scrollEvents, h.zoomEvents, h.noImageEvents], [1, 1, 1]);
      h.bindings.dispose();
      h.bindings.dispose();
      expect([
        h.scroll.disposed,
        h.focus.disposed,
        h.zoom.disposed,
      ], everyElement(isFalse));
      h.scroll.emit();
      h.zoom.value = Matrix4.identity();
      h.noImages.value = false;
      expect([h.scrollEvents, h.zoomEvents, h.noImageEvents], [1, 1, 1]);
    },
  );

  test('dispose before attach is safe and prevents later subscriptions', () {
    final h = _Harness();
    addTearDown(h.dispose);
    h.bindings.dispose();
    h.bindings.attach();
    h.scroll.emit();
    h.zoom.value = Matrix4.diagonal3Values(2, 2, 1);
    h.noImages.value = true;
    expect([h.scrollEvents, h.zoomEvents, h.noImageEvents], [0, 0, 0]);
    expect([
      h.scroll.disposed,
      h.focus.disposed,
      h.zoom.disposed,
    ], everyElement(isFalse));
  });

  testWidgets('requests focus after the frame only while mounted', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    h.bindings.requestFocusAfterFrame(isMounted: () => true);
    expect(h.focus.requests, 0);
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(h.focus.requests, 1);
    h.bindings.requestFocusAfterFrame(isMounted: () => false);
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(h.focus.requests, 1);
  });

  testWidgets('closing before the frame suppresses pending focus requests', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    h.bindings.requestFocusAfterFrame(isMounted: () => true);
    h.bindings.dispose();
    h.bindings.requestFocusAfterFrame(isMounted: () => true);
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(h.focus.requests, 0);
  });
}
