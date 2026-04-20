import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';

class ReaderZoomController {
  ReaderZoomController({
    required TransformationController transformationController,
    required AnimationController resetAnimController,
    required ReaderRuntimeState runtimeState,
    required ReaderIsMounted isMounted,
    required ReaderStateUpdate updateState,
    required ReaderLogEvent logEvent,
    required ReaderLogPayloadBuilder logPayload,
  }) : _transformationController = transformationController,
       _resetAnimController = resetAnimController,
       _runtimeState = runtimeState,
       _isMounted = isMounted,
       _updateState = updateState,
       _logEvent = logEvent,
       _logPayload = logPayload;

  final TransformationController _transformationController;
  final AnimationController _resetAnimController;
  final ReaderRuntimeState _runtimeState;
  final ReaderIsMounted _isMounted;
  final ReaderStateUpdate _updateState;
  final ReaderLogEvent _logEvent;
  final ReaderLogPayloadBuilder _logPayload;

  void onZoomChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (_runtimeState.zoomInteracting) {
      _runtimeState.isZoomed = zoomed;
      return;
    }
    if (zoomed != _runtimeState.isZoomed && _isMounted()) {
      _updateState(() => _runtimeState.isZoomed = zoomed);
    }
  }

  void handlePointerDown(PointerDownEvent _) {
    final previousCount = _runtimeState.activePointerCount;
    _runtimeState.activePointerCount = previousCount + 1;
    if (!_runtimeState.pinchToZoom ||
        previousCount > 1 ||
        _runtimeState.activePointerCount <= 1 ||
        !_isMounted()) {
      return;
    }
    _updateState(() {
      _runtimeState.zoomInteracting = true;
    });
  }

  void handlePointerEnd(PointerEvent _) {
    final previousCount = _runtimeState.activePointerCount;
    _runtimeState.activePointerCount = math.max(0, previousCount - 1);
    if (!_runtimeState.pinchToZoom ||
        previousCount <= 1 ||
        _runtimeState.activePointerCount > 1) {
      return;
    }
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.05;
    if (!_isMounted()) {
      _runtimeState.zoomInteracting = false;
      _runtimeState.isZoomed = zoomed;
      if (!zoomed) {
        _transformationController.value = Matrix4.identity();
      }
      return;
    }
    _updateState(() {
      _runtimeState.zoomInteracting = false;
      _runtimeState.isZoomed = zoomed;
    });
    if (!zoomed) {
      _transformationController.value = Matrix4.identity();
    }
  }

  void handleInteractionStart(ScaleStartDetails _) {
    if (!_isMounted()) {
      _runtimeState.zoomInteracting = true;
      return;
    }
    _updateState(() {
      _runtimeState.zoomInteracting = true;
    });
  }

  void handleInteractionUpdate(ScaleUpdateDetails _) {
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.05;
    if (!_isMounted()) {
      _runtimeState.isZoomed = zoomed;
      return;
    }
    if (zoomed != _runtimeState.isZoomed) {
      _updateState(() {
        _runtimeState.isZoomed = zoomed;
      });
    }
  }

  void handleInteractionEnd(ScaleEndDetails _) {
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.05;
    if (!_isMounted()) {
      _runtimeState.zoomInteracting = _runtimeState.activePointerCount > 1;
      _runtimeState.isZoomed = zoomed;
      if (!zoomed) {
        _transformationController.value = Matrix4.identity();
      }
      return;
    }
    _updateState(() {
      _runtimeState.zoomInteracting = _runtimeState.activePointerCount > 1;
      _runtimeState.isZoomed = zoomed;
    });
    if (!zoomed) {
      _transformationController.value = Matrix4.identity();
    }
  }

  void resetZoom() {
    final controller = _transformationController;
    final startScale = controller.value.getMaxScaleOnAxis();
    _logEvent(
      'Reader zoom reset animated',
      level: 'info',
      source: 'reader_zoom',
      content: _logPayload({
        'trigger': 'manual_reset_button',
        'previousScale': normalizeReaderLogDouble(startScale),
      }),
    );

    final Matrix4 start = controller.value.clone();
    final Matrix4 end = Matrix4.identity();
    _resetAnimController.reset();
    final Animation<double> anim = CurvedAnimation(
      parent: _resetAnimController,
      curve: Curves.easeOutCubic,
    );
    void listener() {
      final t = anim.value;
      final Matrix4 current = Matrix4.zero();
      for (var i = 0; i < 16; i++) {
        current[i] = start[i] + (end[i] - start[i]) * t;
      }
      controller.value = current;
    }

    anim.addListener(listener);
    _resetAnimController.forward().whenComplete(() {
      anim.removeListener(listener);
      controller.value = Matrix4.identity();
      if (!_isMounted()) {
        _runtimeState.isZoomed = false;
        _runtimeState.zoomInteracting = false;
        return;
      }
      _updateState(() {
        _runtimeState.isZoomed = false;
        _runtimeState.zoomInteracting = false;
      });
    });
  }

  void resetZoomImmediately({String reason = 'unspecified'}) {
    final previousScale = _transformationController.value.getMaxScaleOnAxis();
    final hadZoomState =
        _runtimeState.isZoomed ||
        _runtimeState.zoomInteracting ||
        _runtimeState.activePointerCount > 0 ||
        previousScale > 1.001;
    _resetAnimController.stop();
    _transformationController.value = Matrix4.identity();
    _runtimeState.zoomInteracting = false;
    _runtimeState.activePointerCount = 0;
    _runtimeState.isZoomed = false;
    if (hadZoomState) {
      _logEvent(
        'Reader zoom reset immediately',
        level: 'info',
        source: 'reader_zoom',
        content: _logPayload({
          'trigger': reason,
          'previousScale': normalizeReaderLogDouble(previousScale),
        }),
      );
    }
  }
}
