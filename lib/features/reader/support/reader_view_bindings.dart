import 'package:flutter/material.dart';

/// 管理页面级控制器的视图监听订阅与延迟焦点调度。
class ReaderViewBindings {
  ReaderViewBindings({
    required ScrollController scrollController,
    required FocusNode focusNode,
    required TransformationController zoomController,
    required Listenable noImageMode,
    required VoidCallback onNoImageModeChanged,
    required VoidCallback onScrollPositionChanged,
    required VoidCallback onZoomChanged,
  }) : _scrollController = scrollController,
       _focusNode = focusNode,
       _zoomController = zoomController,
       _noImageMode = noImageMode,
       _onNoImageModeChanged = onNoImageModeChanged,
       _onScrollPositionChanged = onScrollPositionChanged,
       _onZoomChanged = onZoomChanged;

  final ScrollController _scrollController;
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
      _zoomController.removeListener(_onZoomChanged);
    }
  }
}
