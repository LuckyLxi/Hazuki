import 'package:flutter/material.dart';

/// Owns reader view subscriptions and the lifetime of its Flutter controllers.
class ReaderViewBindings {
  ReaderViewBindings({
    required ScrollController scrollController,
    required PageController pageController,
    required FocusNode focusNode,
    required TransformationController zoomController,
    required Listenable noImageMode,
    required VoidCallback onNoImageModeChanged,
    required VoidCallback onScrollPositionChanged,
    required VoidCallback onZoomChanged,
  }) : _scrollController = scrollController,
       _pageController = pageController,
       _focusNode = focusNode,
       _zoomController = zoomController,
       _noImageMode = noImageMode,
       _onNoImageModeChanged = onNoImageModeChanged,
       _onScrollPositionChanged = onScrollPositionChanged,
       _onZoomChanged = onZoomChanged;

  final ScrollController _scrollController;
  final PageController _pageController;
  final FocusNode _focusNode;
  final TransformationController _zoomController;
  final Listenable _noImageMode;
  final VoidCallback _onNoImageModeChanged;
  final VoidCallback _onScrollPositionChanged;
  final VoidCallback _onZoomChanged;
  bool _attached = false;
  bool _disposed = false;

  void attach() {
    if (_disposed || _attached) return;
    _attached = true;
    _noImageMode.addListener(_onNoImageModeChanged);
    _scrollController.addListener(_onScrollPositionChanged);
    _zoomController.addListener(_onZoomChanged);
  }

  void requestFocusAfterFrame({required bool Function() isMounted}) {
    if (_disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && isMounted()) _focusNode.requestFocus();
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_attached) {
      _noImageMode.removeListener(_onNoImageModeChanged);
      _scrollController.removeListener(_onScrollPositionChanged);
    }
    _scrollController.dispose();
    _pageController.dispose();
    _focusNode.dispose();
    if (_attached) _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
  }
}
