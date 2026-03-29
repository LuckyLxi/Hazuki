part of '../reader_page.dart';

extension _ReaderZoomActionsExtension on _ReaderPageState {
  void _onZoomChanged() {
    final scale = _zoomController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (_zoomInteracting) {
      _isZoomed = zoomed;
      return;
    }
    if (zoomed != _isZoomed && mounted) {
      _updateReaderState(() => _isZoomed = zoomed);
    }
  }

  void _handleReaderPointerDown(PointerDownEvent _) {
    final previousCount = _activePointerCount;
    _activePointerCount = previousCount + 1;
    if (!_pinchToZoom ||
        previousCount > 1 ||
        _activePointerCount <= 1 ||
        !mounted) {
      return;
    }
    _updateReaderState(() {
      _zoomInteracting = true;
    });
  }

  void _handleReaderPointerEnd(PointerEvent _) {
    final previousCount = _activePointerCount;
    _activePointerCount = math.max(0, previousCount - 1);
    if (!_pinchToZoom || previousCount <= 1 || _activePointerCount > 1) {
      return;
    }
    final zoomed = _zoomController.value.getMaxScaleOnAxis() > 1.05;
    if (!mounted) {
      _zoomInteracting = false;
      _isZoomed = zoomed;
      if (!zoomed) {
        _zoomController.value = Matrix4.identity();
      }
      return;
    }
    _updateReaderState(() {
      _zoomInteracting = false;
      _isZoomed = zoomed;
    });
    if (!zoomed) {
      _zoomController.value = Matrix4.identity();
    }
  }

  void _handleZoomInteractionStart(ScaleStartDetails _) {
    if (!mounted) {
      _zoomInteracting = true;
      return;
    }
    _updateReaderState(() {
      _zoomInteracting = true;
    });
  }

  void _handleZoomInteractionUpdate(ScaleUpdateDetails _) {
    final zoomed = _zoomController.value.getMaxScaleOnAxis() > 1.05;
    if (!mounted) {
      _isZoomed = zoomed;
      return;
    }
    if (zoomed != _isZoomed) {
      _updateReaderState(() {
        _isZoomed = zoomed;
      });
    }
  }

  void _handleZoomInteractionEnd(ScaleEndDetails _) {
    final zoomed = _zoomController.value.getMaxScaleOnAxis() > 1.05;
    if (!mounted) {
      _zoomInteracting = _activePointerCount > 1;
      _isZoomed = zoomed;
      if (!zoomed) {
        _zoomController.value = Matrix4.identity();
      }
      return;
    }
    _updateReaderState(() {
      _zoomInteracting = _activePointerCount > 1;
      _isZoomed = zoomed;
    });
    if (!zoomed) {
      _zoomController.value = Matrix4.identity();
    }
  }

  void _resetZoom() {
    final controller = _zoomController;
    final startScale = controller.value.getMaxScaleOnAxis();
    _logReaderEvent(
      'Reader zoom reset animated',
      source: 'reader_zoom',
      content: _readerLogPayload({
        'trigger': 'manual_reset_button',
        'previousScale': _normalizeLogDouble(startScale),
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
      if (!mounted) {
        _isZoomed = false;
        _zoomInteracting = false;
        return;
      }
      _updateReaderState(() {
        _isZoomed = false;
        _zoomInteracting = false;
      });
    });
  }

  void _resetZoomImmediately({String reason = 'unspecified'}) {
    final previousScale = _zoomController.value.getMaxScaleOnAxis();
    final hadZoomState =
        _isZoomed ||
        _zoomInteracting ||
        _activePointerCount > 0 ||
        previousScale > 1.001;
    _resetAnimController.stop();
    _zoomController.value = Matrix4.identity();
    _zoomInteracting = false;
    _activePointerCount = 0;
    _isZoomed = false;
    if (hadZoomState) {
      _logReaderEvent(
        'Reader zoom reset immediately',
        source: 'reader_zoom',
        content: _readerLogPayload({
          'trigger': reason,
          'previousScale': _normalizeLogDouble(previousScale),
        }),
      );
    }
  }

  Widget _buildZoomableReader({
    required Widget child,
    bool constrained = true,
  }) {
    return InteractiveViewer(
      transformationController: _zoomController,
      panEnabled: _isZoomed || _zoomInteracting,
      scaleEnabled: true,
      panAxis: PanAxis.free,
      boundaryMargin: EdgeInsets.zero,
      constrained: constrained,
      clipBehavior: Clip.hardEdge,
      minScale: 1.0,
      maxScale: 5.0,
      onInteractionStart: _handleZoomInteractionStart,
      onInteractionUpdate: _handleZoomInteractionUpdate,
      onInteractionEnd: _handleZoomInteractionEnd,
      child: child,
    );
  }

  Widget _wrapPageWithPinchZoom({required int index, required Widget child}) {
    if (!_pinchToZoom ||
        _readerMode != ReaderMode.rightToLeft ||
        index != _currentPageIndex) {
      return child;
    }
    return _buildZoomableReader(child: child);
  }

  Widget _buildTopToBottomReaderView() {
    if (!_pinchToZoom || _readerMode != ReaderMode.topToBottom) {
      return _buildReaderListView();
    }
    return _buildZoomableReader(child: _buildReaderListView());
  }
}
