import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/ui_flags.dart';
import '../services/hazuki_source_service.dart';

enum HazukiCachedImageLoadState { idle, deferred, loading, loaded, error }

typedef HazukiCachedImageStateChanged =
    void Function(String url, HazukiCachedImageLoadState state);

const int _hazukiWidgetImageMemoryLimit = 300;
final Map<String, Uint8List> _hazukiWidgetImageMemory = <String, Uint8List>{};

Uint8List? takeHazukiWidgetImageMemory(String url) {
  final bytes = _hazukiWidgetImageMemory[url];
  if (bytes == null) {
    return null;
  }
  _hazukiWidgetImageMemory.remove(url);
  _hazukiWidgetImageMemory[url] = bytes;
  return bytes;
}

void putHazukiWidgetImageMemory(String url, Uint8List bytes) {
  _hazukiWidgetImageMemory.remove(url);
  _hazukiWidgetImageMemory[url] = bytes;
  while (_hazukiWidgetImageMemory.length > _hazukiWidgetImageMemoryLimit) {
    _hazukiWidgetImageMemory.remove(_hazukiWidgetImageMemory.keys.first);
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
    this.loadAnimationDuration = const Duration(milliseconds: 260),
    this.filterQuality = FilterQuality.medium,
    this.deferLoadingWhileScrolling = false,
    this.useShimmerLoading = true,
    this.onStateChanged,
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
  final Duration loadAnimationDuration;
  final FilterQuality filterQuality;
  final bool deferLoadingWhileScrolling;
  final bool useShimmerLoading;
  final HazukiCachedImageStateChanged? onStateChanged;

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

  bool get _noImageModeEnabled {
    return !widget.ignoreNoImageMode && hazukiNoImageModeNotifier.value;
  }

  void _reportState(HazukiCachedImageLoadState state) {
    if (_lastReportedState == state) {
      return;
    }
    _lastReportedState = state;
    widget.onStateChanged?.call(widget.url.trim(), state);
  }

  void _resetStateWithoutImage() {
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
    if (_noImageModeEnabled) {
      _resetStateWithoutImage();
      return;
    }
    if (oldWidget.url != widget.url) {
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
    final cached =
        takeHazukiWidgetImageMemory(normalized) ??
        HazukiSourceService.instance.peekImageBytesFromMemory(normalized);
    if (cached == null) {
      return false;
    }
    if (widget.keepInMemory) {
      putHazukiWidgetImageMemory(normalized, cached);
    }
    _bytes = cached;
    _error = null;
    _loading = false;
    _showLoadedImage = true;
    _useLoadedImageReveal = false;
    _reportState(HazukiCachedImageLoadState.loaded);
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

    final cached =
        takeHazukiWidgetImageMemory(normalized) ??
        HazukiSourceService.instance.peekImageBytesFromMemory(normalized);
    if (cached != null) {
      if (widget.keepInMemory) {
        putHazukiWidgetImageMemory(normalized, cached);
      }
      if (!mounted) {
        _bytes = cached;
        _error = null;
        _loading = false;
        _showLoadedImage = true;
        _useLoadedImageReveal = false;
        return;
      }
      setState(() {
        _bytes = cached;
        _error = null;
        _loading = false;
        _showLoadedImage = true;
        _useLoadedImageReveal = false;
      });
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
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        normalized,
        keepInMemory: widget.keepInMemory,
      );
      if (widget.keepInMemory) {
        putHazukiWidgetImageMemory(normalized, bytes);
      }
      if (!mounted || widget.url.trim() != normalized) {
        return;
      }
      setState(() {
        _bytes = bytes;
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
      if (!mounted || widget.url.trim() != normalized) {
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
    // 图片已加载完成：直接返回，跳过 AnimatedSwitcher
    // 避免 Hero 飞行期间内部状态切换触发额外动画导致闪烁
    if (_bytes != null && !_noImageModeEnabled) {
      final image = Image.memory(
        _bytes!,
        key: ValueKey('loaded-image-${widget.url}'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        gaplessPlayback: true,
        filterQuality: widget.filterQuality,
      );
      if (!widget.animateOnLoad || !_useLoadedImageReveal) {
        return image;
      }
      return AnimatedOpacity(
        key: ValueKey('loaded-image-animate-${widget.url}'),
        opacity: _showLoadedImage ? 1.0 : 0.0,
        duration: widget.loadAnimationDuration,
        curve: Curves.easeOutCubic,
        onEnd: _handleLoadedImageRevealEnd,
        child: AnimatedScale(
          scale: _showLoadedImage ? 1.0 : 0.985,
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
    } else if (_loading) {
      if (widget.loading != null) {
        if (widget.useShimmerLoading) {
          currentWidget = SizedBox(
            key: const ValueKey('loading-stack'),
            width: widget.width,
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 用透明 loading 占位来撑开 Stack 的布局尺寸
                Opacity(opacity: 0.0, child: widget.loading!),
                // shimmer 铺满整个占位区域
                const _HazukiShimmerLoading(),
              ],
            ),
          );
        } else {
          currentWidget = SizedBox(
            key: const ValueKey('loading-static'),
            width: widget.width,
            height: widget.height,
            child: widget.loading,
          );
        }
      } else {
        currentWidget = widget.useShimmerLoading
            ? _HazukiShimmerLoading(
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
}

class HazukiCachedCircleAvatar extends StatefulWidget {
  const HazukiCachedCircleAvatar({
    super.key,
    required this.url,
    this.radius,
    this.fallbackIcon,
    this.ignoreNoImageMode = false,
  });

  final String url;
  final double? radius;
  final Icon? fallbackIcon;
  final bool ignoreNoImageMode;

  @override
  State<HazukiCachedCircleAvatar> createState() =>
      _HazukiCachedCircleAvatarState();
}

class _HazukiCachedCircleAvatarState extends State<HazukiCachedCircleAvatar> {
  Uint8List? _bytes;
  bool _loading = false;

  bool get _noImageModeEnabled {
    return !widget.ignoreNoImageMode && hazukiNoImageModeNotifier.value;
  }

  void _resetWithoutImage() {
    if (!mounted) {
      _bytes = null;
      _loading = false;
      return;
    }
    setState(() {
      _bytes = null;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    hazukiNoImageModeNotifier.addListener(_handleNoImageModeChanged);
    if (_noImageModeEnabled) {
      _resetWithoutImage();
      return;
    }
    _load(widget.url);
  }

  @override
  void didUpdateWidget(covariant HazukiCachedCircleAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_noImageModeEnabled) {
      _resetWithoutImage();
      return;
    }
    if (oldWidget.url != widget.url) {
      _load(widget.url);
    }
  }

  @override
  void dispose() {
    hazukiNoImageModeNotifier.removeListener(_handleNoImageModeChanged);
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
    if (normalized.isEmpty) {
      if (!mounted) {
        _bytes = null;
        _loading = false;
        return;
      }
      setState(() {
        _bytes = null;
        _loading = false;
      });
      return;
    }

    final cached = takeHazukiWidgetImageMemory(normalized);
    if (cached != null) {
      if (!mounted) {
        _bytes = cached;
        _loading = false;
        return;
      }
      setState(() {
        _bytes = cached;
        _loading = false;
      });
      return;
    }

    if (!mounted) {
      _bytes = null;
      _loading = true;
    } else {
      setState(() {
        _bytes = null;
        _loading = true;
      });
    }

    try {
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        normalized,
      );
      putHazukiWidgetImageMemory(normalized, bytes);
      if (!mounted || widget.url.trim() != normalized) {
        return;
      }
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || widget.url.trim() != normalized) {
        return;
      }
      setState(() {
        _bytes = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        key: ValueKey('loaded-avatar-'),
        radius: widget.radius,
        backgroundImage: MemoryImage(_bytes!),
      );
    } else if (_loading) {
      currentWidget = ClipOval(
        key: const ValueKey('loading-avatar'),
        child: _HazukiShimmerLoading(
          width: widget.radius != null ? widget.radius! * 2 : 40,
          height: widget.radius != null ? widget.radius! * 2 : 40,
        ),
      );
    } else {
      currentWidget = CircleAvatar(
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

class _HazukiShimmerLoading extends StatefulWidget {
  const _HazukiShimmerLoading({super.key, this.width, this.height});
  final double? width;
  final double? height;

  @override
  State<_HazukiShimmerLoading> createState() => _HazukiShimmerLoadingState();
}

class _HazukiShimmerLoadingState extends State<_HazukiShimmerLoading>
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
