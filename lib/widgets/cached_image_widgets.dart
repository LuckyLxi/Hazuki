import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/ui_flags.dart';
import '../shared/images/widget_image_memory.dart';
import '../shared/images/widget_image_load_session.dart';
import '../services/source/source_capabilities.dart';
import 'source_image_gateway_scope.dart';

export '../shared/images/widget_image_memory.dart';

enum HazukiCachedImageLoadState { idle, deferred, loading, loaded, error }

typedef HazukiCachedImageStateChanged =
    void Function(String url, HazukiCachedImageLoadState state);

/// Retains the actual bytes and decoded frame used by a visible image. Owners
/// dispose it when the corresponding presentation session ends.
class HazukiCachedImageController {
  ImageStream? _stream;
  ImageInfo? _frame;
  Uint8List? _bytes;
  String _url = '';
  String _sourceKey = '';
  int? _cacheWidth;
  int? _cacheHeight;
  bool _disposed = false;

  Uint8List? bytesFor(String url, {required String sourceKey}) =>
      !_disposed && _url == url.trim() && _sourceKey == sourceKey
      ? _bytes
      : null;

  ui.Image? frameFor(String url, {required String sourceKey}) =>
      bytesFor(url, sourceKey: sourceKey) == null ? null : _frame?.image;

  late final ImageStreamListener _listener = ImageStreamListener((frame, _) {
    _frame?.dispose();
    _frame = frame;
  }, onError: (Object _, StackTrace? _) {});

  void _retain(
    Uint8List bytes, {
    required String url,
    required String sourceKey,
    required int? cacheWidth,
    required int? cacheHeight,
  }) {
    if (_disposed ||
        (identical(_bytes, bytes) &&
            _url == url &&
            _sourceKey == sourceKey &&
            _cacheWidth == cacheWidth &&
            _cacheHeight == cacheHeight)) {
      return;
    }
    _release();
    _bytes = bytes;
    _url = url;
    _sourceKey = sourceKey;
    _cacheWidth = cacheWidth;
    _cacheHeight = cacheHeight;
    _stream = ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      MemoryImage(bytes),
    ).resolve(ImageConfiguration.empty)..addListener(_listener);
  }

  void _release() {
    _stream?.removeListener(_listener);
    _stream = null;
    _frame?.dispose();
    _frame = null;
  }

  void dispose() {
    _disposed = true;
    _release();
    _bytes = null;
  }
}

class HazukiCachedImage extends StatefulWidget {
  const HazukiCachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.loading,
    this.error,
    this.keepInMemory = true,
    this.ignoreNoImageMode = false,
    this.cacheWidth,
    this.cacheHeight,
    this.animateOnLoad = false,
    this.animateOnCacheHit = false,
    this.waitForFirstFrame = false,
    this.revealEnabled = true,
    this.onRevealComplete,
    this.loadAnimationDuration = const Duration(milliseconds: 260),
    this.loadAnimationBeginScale = 0.985,
    this.filterQuality = FilterQuality.medium,
    this.deferLoadingWhileScrolling = false,
    this.useShimmerLoading = true,
    this.sourceKey = '',
    this.onStateChanged,
    this.imageGateway,
    this.controller,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final Widget? loading;
  final Widget? error;
  final bool keepInMemory;
  final bool ignoreNoImageMode;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool animateOnLoad;
  final bool animateOnCacheHit;

  /// Retains the placeholder until the first decoded image frame can be drawn.
  final bool waitForFirstFrame;

  /// Holds the first-frame reveal while an enclosing transition is running.
  /// Only applies when [waitForFirstFrame] is enabled.
  final bool revealEnabled;

  /// Called after the decoded first frame's reveal finishes. Only applies when
  /// [waitForFirstFrame] is enabled.
  final VoidCallback? onRevealComplete;
  final Duration loadAnimationDuration;
  final double loadAnimationBeginScale;
  final FilterQuality filterQuality;
  final bool deferLoadingWhileScrolling;
  final bool useShimmerLoading;
  final String sourceKey;
  final HazukiCachedImageStateChanged? onStateChanged;
  final SourceImageGateway? imageGateway;
  final HazukiCachedImageController? controller;

  @override
  State<HazukiCachedImage> createState() => _HazukiCachedImageState();
}

class _HazukiCachedImageState extends State<HazukiCachedImage> {
  Uint8List? _bytes;
  Object? _error;
  bool _loading = false;
  bool _showLoadedImage = true;
  bool _useLoadedImageReveal = false;
  Timer? _deferredLoadTimer;
  HazukiCachedImageLoadState _lastReportedState =
      HazukiCachedImageLoadState.idle;
  late SourceImageGateway _imageGateway;
  late String _sourceKeySnapshot;
  bool _dependenciesInitialized = false;
  final WidgetImageLoadSession _loadSession = WidgetImageLoadSession();

  bool get _noImageModeEnabled {
    return !widget.ignoreNoImageMode && hazukiNoImageModeNotifier.value;
  }

  String _resolveSourceKey(SourceImageGateway gateway) {
    final explicit = widget.sourceKey.trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return (gateway.activeSourceKey ?? '');
  }

  String get _resolvedSourceKey => _sourceKeySnapshot;

  void _retainPresentationFrame() {
    final bytes = _bytes;
    if (bytes == null) return;
    widget.controller?._retain(
      bytes,
      url: widget.url.trim(),
      sourceKey: _resolvedSourceKey,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
    );
  }

  void _reportState(HazukiCachedImageLoadState state) {
    if (_lastReportedState == state) {
      return;
    }
    _lastReportedState = state;
    widget.onStateChanged?.call(widget.url.trim(), state);
  }

  void _resetStateWithoutImage() {
    _loadSession.invalidate();
    _reportState(HazukiCachedImageLoadState.idle);
    if (!mounted) {
      _bytes = null;
      _error = null;
      _loading = false;
      _showLoadedImage = true;
      _useLoadedImageReveal = false;
      return;
    }
    setState(() {
      _bytes = null;
      _error = null;
      _loading = false;
      _showLoadedImage = true;
      _useLoadedImageReveal = false;
    });
  }

  @override
  void initState() {
    super.initState();
    hazukiNoImageModeNotifier.addListener(_handleNoImageModeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextGateway =
        widget.imageGateway ?? SourceImageGatewayScope.of(context);
    final nextSourceKey = _resolveSourceKey(nextGateway);
    final gatewayChanged =
        _dependenciesInitialized && !identical(_imageGateway, nextGateway);
    final sourceKeyChanged =
        _dependenciesInitialized && _sourceKeySnapshot != nextSourceKey;
    _imageGateway = nextGateway;
    _sourceKeySnapshot = nextSourceKey;
    if (_dependenciesInitialized && !gatewayChanged && !sourceKeyChanged) {
      return;
    }
    _dependenciesInitialized = true;
    if (gatewayChanged || sourceKeyChanged) {
      _cancelDeferredLoad();
      _resetStateWithoutImage();
    }
    if (_noImageModeEnabled) {
      _resetStateWithoutImage();
      return;
    }
    final primed = _primeFromMemory(widget.url);
    if (!primed) {
      // _startLoadOrDefer 内部会调用 Scrollable.recommendDeferredLoadingForContext，
      // 该方法需要访问继承 widget（View.of），在 initState 阶段尚不可用。
      // 推迟到首帧后执行，此时 widget 已完全挂载，可安全访问 inherited widget。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startLoadOrDefer(widget.url);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant HazukiCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final gatewayChanged = oldWidget.imageGateway != widget.imageGateway;
    if (gatewayChanged) {
      _imageGateway =
          widget.imageGateway ?? SourceImageGatewayScope.read(context);
    }
    final nextSourceKey = _resolveSourceKey(_imageGateway);
    final sourceKeyChanged = _sourceKeySnapshot != nextSourceKey;
    _sourceKeySnapshot = nextSourceKey;
    if (gatewayChanged || sourceKeyChanged) {
      _resetStateWithoutImage();
    }
    if (_noImageModeEnabled) {
      _resetStateWithoutImage();
      return;
    }
    if (oldWidget.url != widget.url || sourceKeyChanged || gatewayChanged) {
      _loadSession.invalidate();
      _cancelDeferredLoad();
      final primed = _primeFromMemory(widget.url);
      if (!primed) {
        _startLoadOrDefer(widget.url);
      }
    } else if (oldWidget.deferLoadingWhileScrolling !=
            widget.deferLoadingWhileScrolling &&
        _bytes == null &&
        _error == null) {
      _startLoadOrDefer(widget.url);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.cacheWidth != widget.cacheWidth ||
        oldWidget.cacheHeight != widget.cacheHeight) {
      _retainPresentationFrame();
    }
  }

  @override
  void dispose() {
    _cancelDeferredLoad();
    _reportState(HazukiCachedImageLoadState.idle);
    hazukiNoImageModeNotifier.removeListener(_handleNoImageModeChanged);
    super.dispose();
  }

  void _handleNoImageModeChanged() {
    if (!mounted) {
      return;
    }
    if (_noImageModeEnabled) {
      _resetStateWithoutImage();
      return;
    }
    final primed = _primeFromMemory(widget.url);
    if (!primed) {
      _startLoadOrDefer(widget.url);
    }
  }

  void _cancelDeferredLoad() {
    _deferredLoadTimer?.cancel();
    _deferredLoadTimer = null;
  }

  void _showDeferredLoadingPlaceholder() {
    if (_bytes != null || _loading) {
      return;
    }
    _reportState(HazukiCachedImageLoadState.deferred);
    if (!mounted) {
      _loading = true;
      _error = null;
      _showLoadedImage = false;
      _useLoadedImageReveal = false;
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _showLoadedImage = false;
      _useLoadedImageReveal = false;
    });
  }

  void _startLoadOrDefer(String url) {
    _cancelDeferredLoad();
    final normalized = url.trim();
    if (normalized.isEmpty || _noImageModeEnabled || _bytes != null) {
      return;
    }
    final shouldDefer =
        widget.deferLoadingWhileScrolling &&
        Scrollable.recommendDeferredLoadingForContext(context);
    if (shouldDefer) {
      _showDeferredLoadingPlaceholder();
      _deferredLoadTimer = Timer(const Duration(milliseconds: 120), () {
        _deferredLoadTimer = null;
        if (!mounted || widget.url.trim() != normalized || _bytes != null) {
          return;
        }
        _startLoadOrDefer(normalized);
      });
      return;
    }
    unawaited(_load(normalized));
  }

  bool _primeFromMemory(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      _bytes = null;
      _error = null;
      _loading = false;
      _showLoadedImage = true;
      _useLoadedImageReveal = false;
      return false;
    }
    final sourceKey = _resolvedSourceKey;
    final imageGateway = _imageGateway;
    final cached =
        widget.controller?.bytesFor(normalized, sourceKey: sourceKey) ??
        takeHazukiWidgetImageMemory(normalized, sourceKey: sourceKey) ??
        imageGateway.peekImageBytesFromMemory(normalized, sourceKey: sourceKey);
    if (cached == null) {
      return false;
    }
    if (widget.keepInMemory) {
      putHazukiWidgetImageMemory(normalized, cached, sourceKey: sourceKey);
    }
    _bytes = cached;
    _retainPresentationFrame();
    _error = null;
    _loading = false;
    _useLoadedImageReveal = widget.animateOnLoad && widget.animateOnCacheHit;
    _showLoadedImage = !_useLoadedImageReveal;
    _reportState(HazukiCachedImageLoadState.loaded);
    if (_useLoadedImageReveal) _queueLoadedImageReveal();
    return true;
  }

  void _queueLoadedImageReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showLoadedImage || _bytes == null) {
        return;
      }
      setState(() {
        _showLoadedImage = true;
      });
    });
  }

  void _handleLoadedImageRevealEnd() {
    if (!mounted || !_useLoadedImageReveal || !_showLoadedImage) {
      return;
    }
    setState(() {
      _useLoadedImageReveal = false;
    });
  }

  Future<void> _load(String url) async {
    _cancelDeferredLoad();
    if (_noImageModeEnabled) {
      _resetStateWithoutImage();
      return;
    }

    final normalized = url.trim();
    final request = _loadSession.begin(
      url: normalized,
      gateway: _imageGateway,
      sourceKey: _resolvedSourceKey,
      peekGatewayMemory: true,
      keepInGatewayMemory: widget.keepInMemory,
      keepInWidgetMemory: widget.keepInMemory,
    );
    if (normalized.isEmpty) {
      if (!mounted) {
        _bytes = null;
        _error = null;
        _loading = false;
        _showLoadedImage = true;
        _useLoadedImageReveal = false;
        return;
      }
      setState(() {
        _bytes = null;
        _error = null;
        _loading = false;
        _showLoadedImage = true;
        _useLoadedImageReveal = false;
      });
      return;
    }

    final cached = request.peek();
    if (cached != null) {
      if (!mounted) {
        _bytes = cached;
        _retainPresentationFrame();
        _error = null;
        _loading = false;
        _showLoadedImage = true;
        _useLoadedImageReveal = false;
        return;
      }
      setState(() {
        _bytes = cached;
        _retainPresentationFrame();
        _error = null;
        _loading = false;
        _useLoadedImageReveal =
            widget.animateOnLoad && widget.animateOnCacheHit;
        _showLoadedImage = !_useLoadedImageReveal;
      });
      if (_useLoadedImageReveal) _queueLoadedImageReveal();
      return;
    }

    if (_bytes == null) {
      _reportState(HazukiCachedImageLoadState.loading);
      if (!mounted) {
        _bytes = null;
        _error = null;
        _loading = true;
        _showLoadedImage = false;
      } else {
        setState(() {
          _bytes = null;
          _error = null;
          _loading = true;
          _showLoadedImage = false;
          _useLoadedImageReveal = false;
        });
      }
    }

    try {
      final bytes = await request.download();
      if (!mounted ||
          !request.matches(
            url: widget.url.trim(),
            gateway: _imageGateway,
            sourceKey: _resolvedSourceKey,
          )) {
        return;
      }
      request.retain(bytes);
      setState(() {
        _bytes = bytes;
        _retainPresentationFrame();
        _error = null;
        _loading = false;
        _showLoadedImage = !widget.animateOnLoad;
        _useLoadedImageReveal = widget.animateOnLoad;
      });
      _reportState(HazukiCachedImageLoadState.loaded);
      if (widget.animateOnLoad) {
        _queueLoadedImageReveal();
      }
    } catch (e) {
      if (!mounted ||
          !request.matches(
            url: widget.url.trim(),
            gateway: _imageGateway,
            sourceKey: _resolvedSourceKey,
          )) {
        return;
      }
      setState(() {
        _bytes = null;
        _error = e;
        _loading = false;
        _showLoadedImage = true;
        _useLoadedImageReveal = false;
      });
      _reportState(HazukiCachedImageLoadState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageGateway == null) {
      SourceImageGatewayScope.of(context);
    }
    // 图片已加载完成：直接返回，跳过 AnimatedSwitcher
    // 避免 Hero 飞行期间内部状态切换触发额外动画导致闪烁
    if (_bytes != null && !_noImageModeEnabled) {
      final image = Image.memory(
        _bytes!,
        key: ValueKey('loaded-image-${widget.sourceKey}-${widget.url}'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        gaplessPlayback: true,
        filterQuality: widget.filterQuality,
        frameBuilder: widget.waitForFirstFrame
            ? (context, child, frame, wasSynchronouslyLoaded) =>
                  _HazukiImageFrameReveal(
                    ready: frame != null && widget.revealEnabled,
                    animate: widget.animateOnLoad && _useLoadedImageReveal,
                    duration: widget.loadAnimationDuration,
                    beginScale: widget.loadAnimationBeginScale,
                    onRevealComplete: widget.onRevealComplete,
                    placeholder: _buildLoadingPlaceholder(),
                    child: child,
                  )
            : null,
        errorBuilder: widget.waitForFirstFrame
            ? (context, error, stackTrace) =>
                  widget.error ?? const Icon(Icons.broken_image_outlined)
            : null,
      );
      if (widget.waitForFirstFrame) return image;
      if (!widget.animateOnLoad || !_useLoadedImageReveal) {
        return image;
      }
      return AnimatedOpacity(
        key: ValueKey('loaded-image-animate-${widget.sourceKey}-${widget.url}'),
        opacity: _showLoadedImage ? 1.0 : 0.0,
        duration: widget.loadAnimationDuration,
        curve: Curves.easeOutCubic,
        onEnd: _handleLoadedImageRevealEnd,
        child: AnimatedScale(
          scale: _showLoadedImage ? 1.0 : widget.loadAnimationBeginScale,
          duration: widget.loadAnimationDuration,
          curve: Curves.easeOutCubic,
          child: image,
        ),
      );
    }

    // 未加载完成时构造占位 widget，走 AnimatedSwitcher 做淡入
    final Widget currentWidget;
    if (_noImageModeEnabled) {
      currentWidget = SizedBox(
        key: const ValueKey('no-image'),
        width: widget.width,
        height: widget.height,
      );
    } else if (_loading ||
        (widget.waitForFirstFrame && _error == null && widget.url.isNotEmpty)) {
      currentWidget = _buildLoadingPlaceholder();
    } else if (_error != null) {
      currentWidget =
          widget.error ??
          SizedBox(
            key: const ValueKey('error-image'),
            width: widget.width,
            height: widget.height,
            child: const Icon(Icons.broken_image_outlined),
          );
    } else {
      currentWidget =
          widget.error ??
          SizedBox(
            key: const ValueKey('no-supported'),
            width: widget.width,
            height: widget.height,
            child: const Icon(Icons.image_not_supported_outlined),
          );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: currentWidget,
    );
  }

  Widget _buildLoadingPlaceholder() {
    if (widget.loading != null) {
      if (widget.useShimmerLoading) {
        return SizedBox(
          key: const ValueKey('loading-stack'),
          width: widget.width,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 用透明 loading 占位来撑开 Stack 的布局尺寸
              Opacity(opacity: 0.0, child: widget.loading!),
              // shimmer 铺满整个占位区域
              const HazukiShimmerLoading(),
            ],
          ),
        );
      } else {
        return SizedBox(
          key: const ValueKey('loading-static'),
          width: widget.width,
          height: widget.height,
          child: widget.loading,
        );
      }
    } else {
      return widget.useShimmerLoading
          ? HazukiShimmerLoading(
              key: const ValueKey('loading-shimmer'),
              width: widget.width,
              height: widget.height,
            )
          : SizedBox(
              key: const ValueKey('loading-empty'),
              width: widget.width,
              height: widget.height,
            );
    }
  }
}

class _HazukiImageFrameReveal extends StatefulWidget {
  const _HazukiImageFrameReveal({
    required this.ready,
    required this.animate,
    required this.duration,
    required this.beginScale,
    required this.placeholder,
    required this.child,
    this.onRevealComplete,
  });

  final bool ready;
  final bool animate;
  final Duration duration;
  final double beginScale;
  final Widget placeholder;
  final Widget child;
  final VoidCallback? onRevealComplete;

  @override
  State<_HazukiImageFrameReveal> createState() =>
      _HazukiImageFrameRevealState();
}

class _HazukiImageFrameRevealState extends State<_HazukiImageFrameReveal> {
  bool _visible = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _visible = widget.ready && !widget.animate;
    _finished = _visible;
    if (widget.ready) _revealAfterFrame();
  }

  @override
  void didUpdateWidget(covariant _HazukiImageFrameReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.ready) {
      _visible = false;
      _finished = false;
    } else if (!oldWidget.ready) {
      if (!widget.animate) {
        _visible = true;
        _finished = true;
      }
      _revealAfterFrame();
    }
  }

  void _revealAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.ready) return;
      setState(() {
        _visible = true;
        _finished = !widget.animate;
      });
      if (!widget.animate) widget.onRevealComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return widget.child;
    // Keep the placeholder underneath until the first decoded frame has
    // actually appeared, including throughout its reveal animation.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: widget.placeholder),
        AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          onEnd: () {
            if (mounted && _visible && !_finished) {
              setState(() => _finished = true);
              widget.onRevealComplete?.call();
            }
          },
          child: AnimatedScale(
            scale: _visible ? 1 : widget.beginScale,
            duration: widget.duration,
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class HazukiCachedCircleAvatar extends StatefulWidget {
  const HazukiCachedCircleAvatar({
    super.key,
    required this.url,
    this.radius,
    this.fallbackIcon,
    this.useShimmerFallback = false,
    this.ignoreNoImageMode = false,
    this.imageGateway,
    this.onLoadError,
  });

  final String url;
  final double? radius;
  final Icon? fallbackIcon;
  final bool useShimmerFallback;
  final bool ignoreNoImageMode;
  final SourceImageGateway? imageGateway;
  final VoidCallback? onLoadError;

  @override
  State<HazukiCachedCircleAvatar> createState() =>
      _HazukiCachedCircleAvatarState();
}

class _HazukiCachedCircleAvatarState extends State<HazukiCachedCircleAvatar> {
  Uint8List? _bytes;
  ImageStream? _retainedImageStream;
  final ImageStreamListener _retainedImageListener = ImageStreamListener(
    (image, synchronousCall) => image.dispose(),
  );
  bool _loading = false;
  late SourceImageGateway _imageGateway;
  late String _sourceKeySnapshot;
  bool _dependenciesInitialized = false;
  final WidgetImageLoadSession _loadSession = WidgetImageLoadSession();

  bool get _noImageModeEnabled {
    return !widget.ignoreNoImageMode && hazukiNoImageModeNotifier.value;
  }

  String _resolveSourceKey(SourceImageGateway gateway) {
    return (gateway.activeSourceKey ?? '');
  }

  void _setImageBytes(Uint8List? bytes) {
    if (identical(_bytes, bytes)) return;
    _releaseDecodedImage();
    _bytes = bytes;
    if (bytes == null) return;

    // Route transitions can detach CircleAvatar's decoration painter. Keep a
    // listener for the widget's lifetime so an evicted image stays live and can
    // be painted synchronously when that painter attaches again.
    _retainedImageStream = MemoryImage(bytes).resolve(ImageConfiguration.empty)
      ..addListener(_retainedImageListener);
  }

  void _releaseDecodedImage() {
    _retainedImageStream?.removeListener(_retainedImageListener);
    _retainedImageStream = null;
  }

  void _resetWithoutImage() {
    _loadSession.invalidate();
    if (!mounted) {
      _setImageBytes(null);
      _loading = false;
      return;
    }
    setState(() {
      _setImageBytes(null);
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    hazukiNoImageModeNotifier.addListener(_handleNoImageModeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextGateway =
        widget.imageGateway ?? SourceImageGatewayScope.of(context);
    final nextSourceKey = _resolveSourceKey(nextGateway);
    final gatewayChanged =
        _dependenciesInitialized && !identical(_imageGateway, nextGateway);
    final sourceKeyChanged =
        _dependenciesInitialized && _sourceKeySnapshot != nextSourceKey;
    _imageGateway = nextGateway;
    _sourceKeySnapshot = nextSourceKey;
    if (_dependenciesInitialized && !gatewayChanged && !sourceKeyChanged) {
      return;
    }
    _dependenciesInitialized = true;
    if (_noImageModeEnabled) {
      _resetWithoutImage();
      return;
    }
    _load(widget.url);
  }

  @override
  void didUpdateWidget(covariant HazukiCachedCircleAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final gatewayChanged = oldWidget.imageGateway != widget.imageGateway;
    if (gatewayChanged) {
      _imageGateway =
          widget.imageGateway ?? SourceImageGatewayScope.read(context);
    }
    final nextSourceKey = _resolveSourceKey(_imageGateway);
    final sourceKeyChanged = _sourceKeySnapshot != nextSourceKey;
    _sourceKeySnapshot = nextSourceKey;
    if (_noImageModeEnabled) {
      _resetWithoutImage();
      return;
    }
    if (oldWidget.url != widget.url || gatewayChanged || sourceKeyChanged) {
      _load(widget.url);
    }
  }

  @override
  void dispose() {
    hazukiNoImageModeNotifier.removeListener(_handleNoImageModeChanged);
    _releaseDecodedImage();
    super.dispose();
  }

  void _handleNoImageModeChanged() {
    if (!mounted) {
      return;
    }
    if (_noImageModeEnabled) {
      _resetWithoutImage();
      return;
    }
    unawaited(_load(widget.url));
  }

  Future<void> _load(String url) async {
    if (_noImageModeEnabled) {
      _resetWithoutImage();
      return;
    }

    final normalized = url.trim();
    final request = _loadSession.begin(
      url: normalized,
      gateway: _imageGateway,
      sourceKey: _sourceKeySnapshot,
      peekGatewayMemory: false,
      keepInGatewayMemory: false,
      keepInWidgetMemory: true,
    );
    if (normalized.isEmpty) {
      if (!mounted) {
        _setImageBytes(null);
        _loading = false;
        return;
      }
      setState(() {
        _setImageBytes(null);
        _loading = false;
      });
      return;
    }

    final cached = request.peek();
    if (cached != null) {
      if (!mounted) {
        _setImageBytes(cached);
        _loading = false;
        return;
      }
      setState(() {
        _setImageBytes(cached);
        _loading = false;
      });
      return;
    }

    if (!mounted) {
      _setImageBytes(null);
      _loading = true;
    } else {
      setState(() {
        _setImageBytes(null);
        _loading = true;
      });
    }

    try {
      final bytes = await request.download();
      if (!mounted ||
          !request.matches(
            url: widget.url.trim(),
            gateway: _imageGateway,
            sourceKey: _sourceKeySnapshot,
          )) {
        return;
      }
      request.retain(bytes);
      setState(() {
        _setImageBytes(bytes);
        _loading = false;
      });
    } catch (_) {
      if (!mounted ||
          !request.matches(
            url: widget.url.trim(),
            gateway: _imageGateway,
            sourceKey: _sourceKeySnapshot,
          )) {
        return;
      }
      setState(() {
        _setImageBytes(null);
        _loading = false;
      });
      widget.onLoadError?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageGateway == null) {
      SourceImageGatewayScope.of(context);
    }
    final fallback = widget.fallbackIcon ?? const Icon(Icons.person_outline);
    Widget currentWidget;

    if (_noImageModeEnabled) {
      currentWidget = CircleAvatar(
        key: const ValueKey('no-image'),
        radius: widget.radius,
        child: fallback,
      );
    } else if (_bytes != null) {
      currentWidget = CircleAvatar(
        key: ValueKey('loaded-avatar-${widget.url}'),
        radius: widget.radius,
        backgroundImage: MemoryImage(_bytes!),
      );
    } else if (_loading) {
      currentWidget = ClipOval(
        key: const ValueKey('loading-avatar'),
        child: HazukiShimmerLoading(
          width: widget.radius != null ? widget.radius! * 2 : 40,
          height: widget.radius != null ? widget.radius! * 2 : 40,
        ),
      );
    } else {
      currentWidget = widget.useShimmerFallback
          ? ClipOval(
              key: const ValueKey('fallback-avatar-shimmer'),
              child: HazukiShimmerLoading(
                width: widget.radius != null ? widget.radius! * 2 : 40,
                height: widget.radius != null ? widget.radius! * 2 : 40,
              ),
            )
          : CircleAvatar(
              key: const ValueKey('fallback-avatar'),
              radius: widget.radius,
              child: fallback,
            );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: currentWidget,
    );
  }
}

class HazukiShimmerLoading extends StatefulWidget {
  const HazukiShimmerLoading({super.key, this.width, this.height});
  final double? width;
  final double? height;

  @override
  State<HazukiShimmerLoading> createState() => _HazukiShimmerLoadingState();
}

class _HazukiShimmerLoadingState extends State<HazukiShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surface.withAlpha(128);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final x = -1.5 + _controller.value * 3.0;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment(x - 1.2, -0.2),
              end: Alignment(x + 1.2, 0.2),
            ),
          ),
        );
      },
    );
  }
}
