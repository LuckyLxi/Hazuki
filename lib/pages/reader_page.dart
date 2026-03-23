part of '../main.dart';

enum _ReaderMode {
  topToBottom,
  rightToLeft;

  String get prefsValue => switch (this) {
    _ReaderMode.topToBottom => 'top_to_bottom',
    _ReaderMode.rightToLeft => 'right_to_left',
  };
}

_ReaderMode _readerModeFromRaw(String? raw) {
  return switch (raw) {
    'right_to_left' => _ReaderMode.rightToLeft,
    _ => _ReaderMode.topToBottom,
  };
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.title,
    required this.chapterTitle,
    required this.comicId,
    required this.epId,
    required this.chapterIndex,
    required this.images,
    this.comicTheme,
  });

  final String title;
  final String chapterTitle;
  final String comicId;
  final String epId;
  final int chapterIndex;
  final List<String> images;
  final ThemeData? comicTheme;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  bool get _noImageModeEnabled => hazukiNoImageModeNotifier.value;
  final Map<String, ImageProvider> _providerCache = <String, ImageProvider>{};
  final Map<String, Future<ImageProvider>> _providerFutureCache =
      <String, Future<ImageProvider>>{};
  final Map<String, double> _imageAspectRatioCache = <String, double>{};
  final List<Completer<void>> _decodeWaiters = <Completer<void>>[];

  static const int _maxUnscrambleConcurrency = 5;
  static const bool _defaultImmersiveMode = true;
  static const bool _defaultKeepScreenOn = true;
  static const bool _defaultCustomBrightness = false;
  static const double _defaultBrightnessValue = 0.5;
  static const int _prefetchAroundCount = 14;
  static const int _prefetchAheadCount = 12;
  static const int _prefetchAheadMemoryCount = 4;
  static const int _providerKeepWindow = 280;
  static const int _prefetchBatchSize = 4;
  int _activeUnscrambleTasks = 0;
  int _maxDiskPrefetchedIndex = -1;
  bool _prefetchAheadRunning = false;
  int _currentPageIndex = 0;
  final Map<String, int> _imageIndexMap = <String, int>{};
  final ValueNotifier<int> _pageIndexNotifier = ValueNotifier<int>(0);
  final List<GlobalKey> _itemKeys = <GlobalKey>[];
  List<String> _images = const [];
  bool _loadingImages = true;
  String? _loadImagesError;
  // 阅读设置
  bool _immersiveMode = _defaultImmersiveMode;
  bool _keepScreenOn = _defaultKeepScreenOn;
  bool _customBrightness = _defaultCustomBrightness;
  double _brightnessValue = _defaultBrightnessValue;
  _ReaderMode _readerMode = _ReaderMode.topToBottom;
  bool _tapToTurnPage = false;
  bool _pinchToZoom = false;
  bool _longPressToSave = false;
  // 缩放控制器与当前缩放状态
  final TransformationController _zoomController = TransformationController();
  final Map<String, TransformationController> _listZoomControllers =
      <String, TransformationController>{};
  final Map<String, VoidCallback> _listZoomListeners =
      <String, VoidCallback>{};
  bool _isZoomed = false;
  String? _zoomedListImageUrl;
  bool _rtlZoomInteracting = false;
  // 还原动画控制器
  late final AnimationController _resetAnimController;

  @override
  void initState() {
    super.initState();
    hazukiNoImageModeNotifier.addListener(_handleNoImageModeChanged);
    _scrollController.addListener(_onScrollPrefetch);
    // 缩放变化监听，决定还原按钮可见性
    _zoomController.addListener(_onZoomChanged);
    // 初始化还原动画控制器（200ms，用于平滑归位）
    _resetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    unawaited(_loadReadingSettings());
    unawaited(_recordReadingProgress());

    final initialImages = widget.images
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (initialImages.isNotEmpty) {
      _disposeListZoomControllers();
      _imageAspectRatioCache.clear();
      _images = initialImages;
      _itemKeys.clear();
      _itemKeys.addAll(List.generate(_images.length, (_) => GlobalKey()));
      _rebuildImageIndexMap();
      _loadingImages = false;
      _isZoomed = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefetchAround(0);
        unawaited(_prefetchAheadFrom(0));
      });
    } else {
      unawaited(_loadChapterImages());
    }
  }

  @override
  void dispose() {
    hazukiNoImageModeNotifier.removeListener(_handleNoImageModeChanged);
    _scrollController.removeListener(_onScrollPrefetch);
    _scrollController.dispose();
    _pageController.dispose();
    _disposeListZoomControllers();
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
    _resetAnimController.dispose();
    _pageIndexNotifier.dispose();
    for (final waiter in _decodeWaiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _decodeWaiters.clear();
    unawaited(_restoreReaderDisplay());
    super.dispose();
  }

  /// 监听缩放矩阵变化，更新 _isZoomed 状态以控制还原按钮可见性
  void _onZoomChanged() {
    if (_readerMode != _ReaderMode.rightToLeft) {
      return;
    }
    final scale = _zoomController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (_rtlZoomInteracting) {
      _isZoomed = zoomed;
      return;
    }
    if (zoomed != _isZoomed && mounted) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _handleNoImageModeChanged() {
    _providerCache.clear();
    _providerFutureCache.clear();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _disposeListZoomControllers() {
    for (final entry in _listZoomListeners.entries) {
      _listZoomControllers[entry.key]?.removeListener(entry.value);
    }
    for (final controller in _listZoomControllers.values) {
      controller.dispose();
    }
    _listZoomListeners.clear();
    _listZoomControllers.clear();
    _zoomedListImageUrl = null;
  }

  TransformationController _listZoomControllerFor(String url) {
    final existing = _listZoomControllers[url];
    if (existing != null) {
      return existing;
    }

    final controller = TransformationController();
    void listener() {
      if (!mounted || _readerMode != _ReaderMode.topToBottom) {
        return;
      }
      final zoomed = controller.value.getMaxScaleOnAxis() > 1.05;
      final isActive = _zoomedListImageUrl == url;
      if (zoomed) {
        if (!isActive || !_isZoomed) {
          setState(() {
            _zoomedListImageUrl = url;
            _isZoomed = true;
          });
        }
      } else if (isActive && _isZoomed) {
        setState(() {
          _zoomedListImageUrl = null;
          _isZoomed = false;
        });
      }
    }

    controller.addListener(listener);
    _listZoomControllers[url] = controller;
    _listZoomListeners[url] = listener;
    return controller;
  }

  /// 平滑动画将缩放矩阵还原为原始大小
  void _resetZoom() {
    final controller = _readerMode == _ReaderMode.topToBottom
        ? (_zoomedListImageUrl == null
              ? null
              : _listZoomControllers[_zoomedListImageUrl!])
        : _zoomController;
    if (controller == null) {
      return;
    }

    // 从当前矩阵插值到单位矩阵（即原始 1:1 大小）
    final Matrix4 start = controller.value.clone();
    final Matrix4 end = Matrix4.identity();
    _resetAnimController.reset();
    final Animation<double> anim = CurvedAnimation(
      parent: _resetAnimController,
      curve: Curves.easeOutCubic,
    );
    void listener() {
      final t = anim.value;
      // 对矩阵各元素做线性插值
      final Matrix4 current = Matrix4.zero();
      for (var i = 0; i < 16; i++) {
        current[i] = start[i] + (end[i] - start[i]) * t;
      }
      controller.value = current;
    }

    anim.addListener(listener);
    _resetAnimController.forward().whenComplete(() {
      anim.removeListener(listener);
      // 精确归零，防止浮点误差
      controller.value = Matrix4.identity();
    });
  }

  void _resetZoomImmediately() {
    _resetAnimController.stop();
    if (_readerMode == _ReaderMode.topToBottom) {
      final url = _zoomedListImageUrl;
      if (url != null) {
        _listZoomControllers[url]?.value = Matrix4.identity();
      }
      _zoomedListImageUrl = null;
    } else {
      _zoomController.value = Matrix4.identity();
      _rtlZoomInteracting = false;
    }
    _isZoomed = false;
  }

  Widget _wrapPageWithPinchZoom({required int index, required Widget child}) {
    if (!_pinchToZoom ||
        _readerMode != _ReaderMode.rightToLeft ||
        index != _currentPageIndex) {
      return child;
    }
    return InteractiveViewer(
      transformationController: _zoomController,
      panEnabled: _isZoomed,
      scaleEnabled: true,
      panAxis: PanAxis.free,
      boundaryMargin: EdgeInsets.zero,
      constrained: true,
      clipBehavior: Clip.hardEdge,
      minScale: 1.0,
      maxScale: 5.0,
      onInteractionStart: (_) {
        _rtlZoomInteracting = true;
      },
      onInteractionEnd: (_) {
        if (!mounted) {
          _rtlZoomInteracting = false;
          return;
        }
        final zoomed = _zoomController.value.getMaxScaleOnAxis() > 1.05;
        setState(() {
          _rtlZoomInteracting = false;
          _isZoomed = zoomed;
        });
        if (!zoomed) {
          _zoomController.value = Matrix4.identity();
        }
      },
      child: child,
    );
  }

  Widget _wrapListImageWithPinchZoom({
    required String url,
    required Widget child,
  }) {
    if (!_pinchToZoom || _readerMode != _ReaderMode.topToBottom) {
      return child;
    }
    return InteractiveViewer(
      transformationController: _listZoomControllerFor(url),
      panEnabled: _zoomedListImageUrl == url && _isZoomed,
      scaleEnabled: true,
      panAxis: PanAxis.free,
      boundaryMargin: EdgeInsets.zero,
      constrained: true,
      clipBehavior: Clip.hardEdge,
      minScale: 1.0,
      maxScale: 5.0,
      child: child,
    );
  }

  Future<void> _loadReadingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final immersiveMode =
        prefs.getBool('reader_immersive_mode') ?? _defaultImmersiveMode;
    final keepScreenOn =
        prefs.getBool('reader_keep_screen_on') ?? _defaultKeepScreenOn;
    final customBrightness =
        prefs.getBool('reader_custom_brightness') ?? _defaultCustomBrightness;
    final brightnessValue =
        prefs.getDouble('reader_brightness_value') ?? _defaultBrightnessValue;
    final readerMode = _readerModeFromRaw(
      prefs.getString('reader_reading_mode'),
    );
    if (!mounted) return;
    setState(() {
      _immersiveMode = immersiveMode;
      _keepScreenOn = keepScreenOn;
      _customBrightness = customBrightness;
      _brightnessValue = brightnessValue.clamp(0.0, 1.0);
      _readerMode = readerMode;
      _tapToTurnPage = prefs.getBool('reader_tap_to_turn_page') ?? false;
      _pinchToZoom = prefs.getBool('reader_pinch_to_zoom') ?? false;
      _longPressToSave = prefs.getBool('reader_long_press_save') ?? false;
    });
    await _applyReaderDisplaySettings();
  }

  Future<void> _applyReaderDisplaySettings() async {
    if (_immersiveMode) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    if (Platform.isAndroid) {
      try {
        await _readerDisplayChannel.invokeMethod<void>('setKeepScreenOn', {
          'enabled': _keepScreenOn,
        });
        await _readerDisplayChannel.invokeMethod<bool>('setReaderBrightness', {
          'value': _customBrightness ? _brightnessValue : null,
        });
      } catch (_) {}
    }
  }

  Future<void> _restoreReaderDisplay() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (Platform.isAndroid) {
      try {
        await _readerDisplayChannel.invokeMethod<void>('setKeepScreenOn', {
          'enabled': false,
        });
        await _readerDisplayChannel.invokeMethod<bool>('setReaderBrightness', {
          'value': null,
        });
      } catch (_) {}
    }
  }

  Future<void> _recordReadingProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = {
        'epId': widget.epId,
        'title': widget.chapterTitle,
        'index': widget.chapterIndex,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(
        'reading_progress_${widget.comicId}',
        jsonEncode(progress),
      );
    } catch (_) {}
  }

  /// 根据阅读设置包装图片组件：长按保存
  /// 注意：双指缩放由整屏 InteractiveViewer 处理，此处不再单独包裹缩放逻辑
  Widget _wrapImageWidget(Widget imageWidget, String url) {
    Widget result = imageWidget;
    if (_longPressToSave) {
      result = GestureDetector(
        onLongPress: () => _showSaveImageDialog(url),
        child: result,
      );
    }
    return result;
  }

  /// 长按保存图片确认弹窗
  Future<void> _showSaveImageDialog(String imageUrl) async {
    unawaited(HapticFeedback.heavyImpact());
    final strings = l10n(context);
    final shouldSave = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInBack,
          ).value,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogContext, anim1, anim2) {
        return AlertDialog(
          title: Text(strings.readerSaveImageTitle),
          content: Text(strings.readerSaveImageContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(strings.commonSave),
            ),
          ],
        );
      },
    );
    if (shouldSave != true || !mounted) return;
    try {
      Uint8List bytes;
      // 优先从已解扰的缓存中获取图片，避免保存切片原图
      final cachedProvider = _providerCache[imageUrl];
      if (cachedProvider is MemoryImage) {
        bytes = cachedProvider.bytes;
      } else {
        // 缓存中没有，重新下载并解扰
        final rawBytes = await HazukiSourceService.instance.downloadImageBytes(
          imageUrl,
          comicId: widget.comicId,
          epId: widget.epId,
        );
        final segments = _calcJmSegments(widget.epId, imageUrl);
        if (segments > 1 && !imageUrl.toLowerCase().endsWith('.gif')) {
          bytes = await _unscrambleJmImage(rawBytes, segments);
        } else {
          bytes = rawBytes;
        }
      }
      final uri = Uri.tryParse(imageUrl);
      final lastSegment = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : '';
      final defaultName = 'hazuki_${DateTime.now().millisecondsSinceEpoch}.png';
      final fileName = lastSegment.isEmpty
          ? defaultName
          : lastSegment.split('?').first;
      // 解扰后的图片是 PNG 格式，替换原扩展名
      final saveName = fileName.replaceAll(
        RegExp(r'\.(webp|jpg|jpeg)$', caseSensitive: false),
        '.png',
      );
      final directory = Directory('/storage/emulated/0/Pictures/Hazuki');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File('${directory.path}/$saveName');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(context, strings.comicDetailSavedToPath(file.path)),
      );
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(
          context,
          strings.comicDetailSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  void _rebuildImageIndexMap() {
    _imageIndexMap
      ..clear()
      ..addEntries(
        _images.asMap().entries.map((entry) {
          return MapEntry(entry.value, entry.key);
        }),
      );
  }

  void _trimProviderCachesAround(int centerIndex) {
    final keepStart = centerIndex - 120;
    final keepEnd = centerIndex + _providerKeepWindow;

    final staleProviderKeys = <String>[];
    _providerCache.forEach((key, _) {
      final index = _imageIndexMap[key];
      if (index == null || index < keepStart || index > keepEnd) {
        staleProviderKeys.add(key);
      }
    });
    for (final key in staleProviderKeys) {
      _providerCache.remove(key);
    }

    final staleFutureKeys = <String>[];
    _providerFutureCache.forEach((key, _) {
      final index = _imageIndexMap[key];
      if (index == null || index < keepStart || index > keepEnd) {
        staleFutureKeys.add(key);
      }
    });
    for (final key in staleFutureKeys) {
      _providerFutureCache.remove(key);
    }
  }

  Future<void> _loadChapterImages() async {
    try {
      final images = await HazukiSourceService.instance.loadChapterImages(
        comicId: widget.comicId,
        epId: widget.epId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _disposeListZoomControllers();
        _imageAspectRatioCache.clear();
        _images = images.where((e) => e.trim().isNotEmpty).toList();
        _itemKeys.clear();
        _itemKeys.addAll(List.generate(_images.length, (_) => GlobalKey()));
        _rebuildImageIndexMap();
        _loadingImages = false;
        _loadImagesError = null;
        _currentPageIndex = 0;
        _isZoomed = false;
      });
      _pageIndexNotifier.value = 0;
      if (!_noImageModeEnabled) {
        _prefetchAround(0);
        unawaited(_prefetchAheadFrom(0));
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingImages = false;
        _loadImagesError = l10n(context).readerChapterLoadFailed('$e');
      });
    }
  }

  void _onScrollPrefetch() {
    if (_noImageModeEnabled ||
        !_scrollController.hasClients ||
        _images.isEmpty) {
      return;
    }
    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) {
      return;
    }

    int normalizedIndex = _currentPageIndex;

    // 通过遍历已挂载的组件位置来精确寻找当前屏幕最顶端可见的漫画页
    for (var i = 0; i < _images.length; i++) {
      if (i >= _itemKeys.length) break;
      final ctx = _itemKeys[i].currentContext;
      if (ctx != null) {
        final renderObject = ctx.findRenderObject();
        if (renderObject is RenderBox && renderObject.hasSize) {
          final positionY = renderObject.localToGlobal(Offset.zero).dy;
          final itemHeight = renderObject.size.height;
          // 当前图片的底部如果还在屏幕顶部之下一定距离（如 50 像素阈值），
          // 说明该图片目前是视野中最靠上可见的完整或部分图片。
          if (positionY + itemHeight > 50) {
            normalizedIndex = i;
            break;
          }
        }
      }
    }

    if (_currentPageIndex != normalizedIndex) {
      _currentPageIndex = normalizedIndex;
      _pageIndexNotifier.value = normalizedIndex;
    }
    _prefetchAround(normalizedIndex);
    unawaited(_prefetchAheadFrom(normalizedIndex));
  }

  void _prefetchAround(int currentIndex) {
    var start = currentIndex - _prefetchAroundCount;
    if (start < 0) {
      start = 0;
    }
    final max = _images.length;
    var end = currentIndex + _prefetchAroundCount;
    if (end > max) {
      end = max;
    }

    for (var i = start; i < end; i++) {
      final url = _images[i];
      if (_providerCache.containsKey(url) ||
          _providerFutureCache.containsKey(url)) {
        continue;
      }
      unawaited(_getOrCreateImageProviderFuture(url));
    }

    _trimProviderCachesAround(start);
  }

  Future<void> _prefetchAheadFrom(int currentIndex) async {
    if (_prefetchAheadRunning || _images.isEmpty) {
      return;
    }
    var start = currentIndex + 1;
    if (start < 0) {
      start = 0;
    }
    if (start >= _images.length) {
      return;
    }

    _prefetchAheadRunning = true;
    try {
      final endExclusive = (start + _prefetchAheadCount) < _images.length
          ? (start + _prefetchAheadCount)
          : _images.length;

      for (var batchStart = start; batchStart < endExclusive;) {
        final batchEnd = (batchStart + _prefetchBatchSize) < endExclusive
            ? (batchStart + _prefetchBatchSize)
            : endExclusive;

        final futures = <Future<void>>[];
        for (var i = batchStart; i < batchEnd; i++) {
          final shouldKeepInMemory = i < start + _prefetchAheadMemoryCount;
          final shouldDownloadForDisk = i > _maxDiskPrefetchedIndex;
          if (!shouldKeepInMemory && !shouldDownloadForDisk) {
            continue;
          }

          final url = _images[i];
          if (url.trim().isEmpty) {
            continue;
          }

          if (HazukiSourceService.instance.isLocalImagePath(url)) {
            if (shouldKeepInMemory) {
              unawaited(_getOrCreateImageProviderFuture(url));
            }
            continue;
          }

          futures.add(
            HazukiSourceService.instance
                .downloadImageBytes(
                  url,
                  comicId: widget.comicId,
                  epId: widget.epId,
                  keepInMemory: shouldKeepInMemory,
                )
                .then((_) {})
                .catchError((_) {}),
          );

          if (shouldKeepInMemory) {
            unawaited(_getOrCreateImageProviderFuture(url));
          }
        }

        if (futures.isNotEmpty) {
          await Future.wait(futures);
        }

        batchStart = batchEnd;
      }

      if (endExclusive - 1 > _maxDiskPrefetchedIndex) {
        _maxDiskPrefetchedIndex = endExclusive - 1;
      }
    } finally {
      _prefetchAheadRunning = false;
    }
  }

  Future<void> _acquireUnscramblePermit() async {
    if (_activeUnscrambleTasks < _maxUnscrambleConcurrency) {
      _activeUnscrambleTasks++;
      return;
    }
    final waiter = Completer<void>();
    _decodeWaiters.add(waiter);
    await waiter.future;
    _activeUnscrambleTasks++;
  }

  void _releaseUnscramblePermit() {
    if (_activeUnscrambleTasks > 0) {
      _activeUnscrambleTasks--;
    }
    while (_decodeWaiters.isNotEmpty) {
      final waiter = _decodeWaiters.removeAt(0);
      if (!waiter.isCompleted) {
        waiter.complete();
        break;
      }
    }
  }

  Future<ImageProvider> _getOrCreateImageProviderFuture(String url) {
    final existing = _providerFutureCache[url];
    if (existing != null) {
      return existing;
    }

    final created = _buildImageProvider(url)
        .then((provider) async {
          _providerCache[url] = provider;
          if (mounted) {
            try {
              await precacheImage(provider, context);
            } catch (_) {}
          }
          return provider;
        })
        .catchError((Object error, StackTrace stackTrace) {
          _providerFutureCache.remove(url);
          throw error;
        });

    _providerFutureCache[url] = created;
    return created;
  }

  Future<void> _rememberAspectRatioFromBytes(String url, Uint8List bytes) async {
    if (_imageAspectRatioCache.containsKey(url)) {
      return;
    }
    try {
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (image.height <= 0) {
        return;
      }
      _imageAspectRatioCache[url] = image.width / image.height;
    } catch (_) {}
  }

  int _calcJmSegments(String epId, String imageUrl) {
    const scrambleId = 220980;
    final id = int.tryParse(epId) ?? 0;
    if (id < scrambleId) {
      return 0;
    }
    if (id < 268850) {
      return 10;
    }

    final uri = Uri.tryParse(imageUrl);
    final last = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : imageUrl.split('/').last;
    final pictureName = last.endsWith('.webp')
        ? last.substring(0, last.length - 5)
        : last;

    final digest = md5.convert(utf8.encode('$id$pictureName')).toString();
    final charCode = digest.codeUnitAt(digest.length - 1);

    if (id > 421926) {
      final remainder = charCode % 8;
      return remainder * 2 + 2;
    }
    final remainder = charCode % 10;
    return remainder * 2 + 2;
  }

  Future<Uint8List> _unscrambleJmImage(Uint8List data, int segments) async {
    final codec = await instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final src = await image.toByteData(format: ImageByteFormat.rawRgba);
    if (src == null) {
      return data;
    }

    final blockSize = height ~/ segments;
    final remainder = height % segments;
    final srcBytes = src.buffer.asUint8List();
    final dstBytes = Uint8List(srcBytes.length);

    var destY = 0;
    for (var i = segments - 1; i >= 0; i--) {
      final startY = i * blockSize;
      final currentHeight = blockSize + (i == segments - 1 ? remainder : 0);
      final rowBytes = width * 4;
      for (var y = 0; y < currentHeight; y++) {
        final srcOffset = ((startY + y) * width) * 4;
        final dstOffset = ((destY + y) * width) * 4;
        dstBytes.setRange(dstOffset, dstOffset + rowBytes, srcBytes, srcOffset);
      }
      destY += currentHeight;
    }

    final buffer = await ImmutableBuffer.fromUint8List(dstBytes);
    final descriptor = ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: PixelFormat.rgba8888,
      rowBytes: width * 4,
    );
    final outCodec = await descriptor.instantiateCodec();
    final outFrame = await outCodec.getNextFrame();
    final png = await outFrame.image.toByteData(format: ImageByteFormat.png);
    if (png == null) {
      return data;
    }
    return png.buffer.asUint8List();
  }

  Future<ImageProvider> _buildImageProvider(String url) async {
    final sourceService = HazukiSourceService.instance;
    if (_noImageModeEnabled) {
      throw StateError('no-image mode enabled');
    }

    if (sourceService.isLocalImagePath(url)) {
      final file = File(sourceService.normalizeLocalImagePath(url));
      try {
        final bytes = await file.readAsBytes();
        await _rememberAspectRatioFromBytes(url, bytes);
      } catch (_) {}
      return FileImage(file);
    }

    final segments = sourceService.calculateJmImageSegments(widget.epId, url);
    if (segments <= 1 || url.toLowerCase().endsWith('.gif')) {
      return NetworkImage(url);
    }

    await _acquireUnscramblePermit();
    try {
      final prepared = await sourceService.prepareChapterImageData(
        url,
        comicId: widget.comicId,
        epId: widget.epId,
      );
      await _rememberAspectRatioFromBytes(url, prepared.bytes);
      return MemoryImage(prepared.bytes);
    } catch (_) {
      final rawBytes = await sourceService.downloadImageBytes(
        url,
        comicId: widget.comicId,
        epId: widget.epId,
        keepInMemory: true,
      );
      final restoredBytes = await _unscrambleJmImage(rawBytes, segments);
      await _rememberAspectRatioFromBytes(url, restoredBytes);
      return MemoryImage(restoredBytes);
    } finally {
      _releaseUnscramblePermit();
    }
  }

  Widget _buildReaderListView() {
    return ListView.builder(
      key: ValueKey('${widget.comicId}-${widget.epId}'),
      padding: EdgeInsets.zero,
      itemCount: _images.length,
      controller: _scrollController,
      physics: (_pinchToZoom && _isZoomed)
          ? const NeverScrollableScrollPhysics()
          : const _ReaderScrollPhysics(),
      itemBuilder: (context, index) {
        final url = _images[index];
        final cachedProvider = _providerCache[url];
        final placeholderAspectRatio = _imageAspectRatioCache[url] ?? (3 / 4);

        if (_noImageModeEnabled) {
          return AspectRatio(
            key: index < _itemKeys.length ? _itemKeys[index] : null,
            aspectRatio: 3 / 4,
            child: const SizedBox.expand(),
          );
        }

        Widget buildImage(ImageProvider provider) {
          return _wrapImageWidget(
            _wrapListImageWithPinchZoom(
              url: url,
              child: Image(
                key: ValueKey(url),
                image: provider,
                fit: BoxFit.fitWidth,
                width: double.infinity,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return const ColoredBox(color: Colors.black);
                },
                errorBuilder: (_, _, _) {
                  return Container(
                    height: 120,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  );
                },
              ),
            ),
            url,
          );
        }

        Widget content;
        if (cachedProvider != null) {
          content = buildImage(cachedProvider);
        } else {
          content = FutureBuilder<ImageProvider>(
            key: ValueKey(url),
            future: _getOrCreateImageProviderFuture(url),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return buildImage(snapshot.data!);
              }
              if (snapshot.hasError) {
                return AspectRatio(
                  aspectRatio: placeholderAspectRatio,
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                );
              }
              return AspectRatio(
                aspectRatio: placeholderAspectRatio,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          );
        }

        return Container(
          key: index < _itemKeys.length ? _itemKeys[index] : null,
          child: content,
        );
      },
    );
  }

  Widget _buildReaderPageView() {
    return PageView.builder(
      key: ValueKey('${widget.comicId}-${widget.epId}-rtl'),
      controller: _pageController,
      reverse: false,
      allowImplicitScrolling: true,
      itemCount: _images.length,
      physics: (_pinchToZoom && (_isZoomed || _rtlZoomInteracting))
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: (index) {
        final pageChanged = _currentPageIndex != index;
        final zoomWasActive = _isZoomed;
        _resetZoomImmediately();
        if (pageChanged || zoomWasActive) {
          setState(() {
            _currentPageIndex = index;
          });
        }
        _pageIndexNotifier.value = index;
        if (!_noImageModeEnabled) {
          _prefetchAround(index);
          unawaited(_prefetchAheadFrom(index));
        }
      },
      itemBuilder: (context, index) {
        final url = _images[index];
        final cachedProvider = _providerCache[url];

        if (_noImageModeEnabled) {
          return const SizedBox.expand();
        }

        Widget buildImage(ImageProvider provider) {
          return _wrapImageWidget(
            _wrapPageWithPinchZoom(
              index: index,
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Image(
                    key: ValueKey('reader-page-$url'),
                    image: provider,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded || frame != null) {
                        return child;
                      }
                      return const ColoredBox(color: Colors.black);
                    },
                    errorBuilder: (_, _, _) {
                      return Container(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      );
                    },
                  ),
                ),
              ),
            ),
            url,
          );
        }

        if (cachedProvider != null) {
          return buildImage(cachedProvider);
        }

        return FutureBuilder<ImageProvider>(
          key: ValueKey('reader-page-future-$url'),
          future: _getOrCreateImageProviderFuture(url),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return buildImage(snapshot.data!);
            }
            if (snapshot.hasError) {
              return Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              );
            }
            return const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _goToReaderPage(int index) async {
    if (!_pageController.hasClients || _images.isEmpty) {
      return;
    }
    final target = math.max(0, math.min(index, _images.length - 1));
    if (target == _currentPageIndex) {
      return;
    }
    await _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToPreviousPage() async {
    if (_currentPageIndex <= 0) {
      return;
    }
    await _goToReaderPage(_currentPageIndex - 1);
  }

  Future<void> _goToNextPage() async {
    if (_currentPageIndex >= _images.length - 1) {
      return;
    }
    await _goToReaderPage(_currentPageIndex + 1);
  }

  Widget _wrapReaderTapPaging(Widget child) {
    final tapPagingEnabled =
        _readerMode == _ReaderMode.rightToLeft &&
        _tapToTurnPage &&
        !(_pinchToZoom && (_isZoomed || _rtlZoomInteracting));
    if (!tapPagingEnabled) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            final isLeftSide =
                details.localPosition.dx <= constraints.maxWidth / 2;
            if (isLeftSide) {
              unawaited(_goToPreviousPage());
            } else {
              unawaited(_goToNextPage());
            }
          },
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inheritedTheme = Theme.of(context);
    final readerTheme = widget.comicTheme ?? inheritedTheme;
    final readerBg = readerTheme.scaffoldBackgroundColor;

    if (_loadingImages) {
      return AnimatedTheme(
        data: readerTheme,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: Scaffold(
          backgroundColor: readerBg,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_loadImagesError != null) {
      return AnimatedTheme(
        data: readerTheme,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: Scaffold(
          backgroundColor: readerBg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loadImagesError!,
                    style: TextStyle(
                      color: readerTheme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _loadingImages = true;
                        _loadImagesError = null;
                      });
                      unawaited(_loadChapterImages());
                    },
                    child: Text(l10n(context).commonRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_images.isEmpty) {
      return AnimatedTheme(
        data: readerTheme,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: Scaffold(
          backgroundColor: readerBg,
          body: Center(
            child: Text(
              l10n(context).readerCurrentChapterNoImages,
              style: TextStyle(color: readerTheme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return AnimatedTheme(
      data: readerTheme,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: Scaffold(
        backgroundColor: readerBg,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              _wrapReaderTapPaging(
                _readerMode == _ReaderMode.rightToLeft
                    ? _buildReaderPageView()
                    : _buildReaderListView(),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _pageIndexNotifier,
                    builder: (context, pageIndex, _) {
                      final pageText =
                          '${widget.chapterTitle}  ${pageIndex + 1}/${_images.length}';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          pageText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // 还原按钮：使用 AnimatedScale + AnimatedOpacity 实现弹出/收起动画
              if (_pinchToZoom)
                Positioned(
                  bottom: 72,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: IgnorePointer(
                      ignoring: !_isZoomed,
                      child: AnimatedScale(
                        scale: _isZoomed ? 1.0 : 0.7,
                        duration: const Duration(milliseconds: 220),
                        curve: _isZoomed
                            ? Curves.easeOutBack
                            : Curves.easeInCubic,
                        child: AnimatedOpacity(
                          opacity: _isZoomed ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: GestureDetector(
                            onTap: _resetZoom,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.zoom_out_map_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n(context).readerResetZoom,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 闃呰鍣ㄤ笓鐢ㄦ粴鍔ㄧ墿鐞嗗紩鎿庯細
/// - 鍩轰簬 ClampingScrollPhysics锛屽埌椤?鍒板簳涓嶄細瓒婄晫鍥炲脊
/// - 浣跨敤榛樿鐢╁姩閫熷害锛?000 px/s锛夛紝閬垮厤杩囧ぇ鎯€у鑷村揩閫熶笅鍒掓椂鍐插洖椤堕儴
class _ReaderScrollPhysics extends ClampingScrollPhysics {
  const _ReaderScrollPhysics({super.parent});

  @override
  _ReaderScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ReaderScrollPhysics(parent: buildParent(ancestor));
  }
}
