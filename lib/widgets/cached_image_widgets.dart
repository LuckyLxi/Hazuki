import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/ui_flags.dart';
import '../services/hazuki_source_service.dart';

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

  @override
  State<HazukiCachedImage> createState() => _HazukiCachedImageState();
}

class _HazukiCachedImageState extends State<HazukiCachedImage> {
  Uint8List? _bytes;
  Object? _error;
  bool _loading = false;

  bool get _noImageModeEnabled {
    return !widget.ignoreNoImageMode && hazukiNoImageModeNotifier.value;
  }

  void _resetStateWithoutImage() {
    if (!mounted) {
      _bytes = null;
      _error = null;
      _loading = false;
      return;
    }
    setState(() {
      _bytes = null;
      _error = null;
      _loading = false;
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
      _load(widget.url);
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
      final primed = _primeFromMemory(widget.url);
      if (!primed) {
        _load(widget.url);
      }
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
      _resetStateWithoutImage();
      return;
    }
    final primed = _primeFromMemory(widget.url);
    if (!primed) {
      unawaited(_load(widget.url));
    }
  }

  bool _primeFromMemory(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      _bytes = null;
      _error = null;
      _loading = false;
      return false;
    }
    final cached = takeHazukiWidgetImageMemory(normalized);
    if (cached == null) {
      return false;
    }
    _bytes = cached;
    _error = null;
    _loading = false;
    return true;
  }

  Future<void> _load(String url) async {
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
        return;
      }
      setState(() {
        _bytes = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    final cached = takeHazukiWidgetImageMemory(normalized);
    if (cached != null) {
      if (!mounted) {
        _bytes = cached;
        _error = null;
        _loading = false;
        return;
      }
      setState(() {
        _bytes = cached;
        _error = null;
        _loading = false;
      });
      return;
    }

    if (_bytes == null) {
      if (!mounted) {
        _bytes = null;
        _error = null;
        _loading = true;
      } else {
        setState(() {
          _bytes = null;
          _error = null;
          _loading = true;
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
      });
    } catch (e) {
      if (!mounted || widget.url.trim() != normalized) {
        return;
      }
      setState(() {
        _bytes = null;
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_noImageModeEnabled) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }

    if (_loading) {
      return widget.loading ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    }

    if (_error != null) {
      return widget.error ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Icon(Icons.broken_image_outlined),
          );
    }

    return widget.error ??
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Icon(Icons.image_not_supported_outlined),
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

    if (_noImageModeEnabled) {
      return CircleAvatar(radius: widget.radius, child: fallback);
    }

    if (_bytes != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: MemoryImage(_bytes!),
      );
    }

    if (_loading) {
      return CircleAvatar(
        radius: widget.radius,
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return CircleAvatar(radius: widget.radius, child: fallback);
  }
}
