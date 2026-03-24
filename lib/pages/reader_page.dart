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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
  static const bool _defaultPageIndicator = false;
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
  bool _controlsVisible = false;
  bool _sliderDragging = false;
  double _sliderDragValue = 0;
  List<String> _images = const [];
  bool _loadingImages = true;
  String? _loadImagesError;
  ComicDetailsData? _chapterDetailsCache;
  bool _chapterPanelLoading = false;
  // 阅读设置
  bool _immersiveMode = _defaultImmersiveMode;
  bool _keepScreenOn = _defaultKeepScreenOn;
  bool _customBrightness = _defaultCustomBrightness;
  double _brightnessValue = _defaultBrightnessValue;
  _ReaderMode _readerMode = _ReaderMode.topToBottom;
  bool _tapToTurnPage = false;
  bool _pageIndicator = _defaultPageIndicator;
  bool _pinchToZoom = false;
  bool _longPressToSave = false;
  // 缩放控制器与当前缩放状态
  final TransformationController _zoomController = TransformationController();
  bool _isZoomed = false;
  bool _zoomInteracting = false;
  int _activePointerCount = 0;
  bool get _zoomGestureActive =>
      _pinchToZoom && (_isZoomed || _zoomInteracting || _activePointerCount > 1);
  bool get _pageNavigationLocked =>
      _pinchToZoom && (_zoomInteracting || _isZoomed || _activePointerCount > 1);
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
      _zoomController.value = Matrix4.identity();
      _imageAspectRatioCache.clear();
      _images = initialImages;
      _itemKeys.clear();
      _itemKeys.addAll(List.generate(_images.length, (_) => GlobalKey()));
      _rebuildImageIndexMap();
      _loadingImages = false;
      _isZoomed = false;
      _zoomInteracting = false;
      _activePointerCount = 0;
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
    final scale = _zoomController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (_zoomInteracting) {
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

  void _handleReaderPointerDown(PointerDownEvent _) {
    final previousCount = _activePointerCount;
    _activePointerCount = previousCount + 1;
    if (!_pinchToZoom || previousCount > 1 || _activePointerCount <= 1 || !mounted) {
      return;
    }
    setState(() {
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
    setState(() {
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
    setState(() {
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
      setState(() {
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
    setState(() {
      _zoomInteracting = _activePointerCount > 1;
      _isZoomed = zoomed;
    });
    if (!zoomed) {
      _zoomController.value = Matrix4.identity();
    }
  }

  /// 平滑动画将缩放矩阵还原为原始大小
  void _resetZoom() {
    final controller = _zoomController;

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
      if (!mounted) {
        _isZoomed = false;
        _zoomInteracting = false;
        return;
      }
      setState(() {
        _isZoomed = false;
        _zoomInteracting = false;
      });
    });
  }

  void _resetZoomImmediately() {
    _resetAnimController.stop();
    _zoomController.value = Matrix4.identity();
    _zoomInteracting = false;
    _activePointerCount = 0;
    _isZoomed = false;
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
        _readerMode != _ReaderMode.rightToLeft ||
        index != _currentPageIndex) {
      return child;
    }
    return _buildZoomableReader(child: child);
  }

  Widget _buildTopToBottomReaderView() {
    if (!_pinchToZoom || _readerMode != _ReaderMode.topToBottom) {
      return _buildReaderListView();
    }
    return _buildZoomableReader(child: _buildReaderListView());
  }

  Future<void> _loadReadingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final immersiveMode =
        prefs.getBool('reader_immersive_mode') ?? _defaultImmersiveMode;
    final keepScreenOn =
        prefs.getBool('reader_keep_screen_on') ?? _defaultKeepScreenOn;
    final customBrightness =
        prefs.getBool('reader_custom_brightness') ?? _defaultCustomBrightness;
    final pageIndicator =
        prefs.getBool('reader_page_indicator') ?? _defaultPageIndicator;
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
      _pageIndicator = pageIndicator;
      _brightnessValue = math.max(0.0, math.min(brightnessValue, 1.0));
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

  void _toggleControlsVisibility() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  void _openReaderSettingsDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _setDisplayedPageIndex(int index) {
    if (_images.isEmpty) {
      if (_pageIndexNotifier.value != 0) {
        _pageIndexNotifier.value = 0;
      }
      return;
    }
    final normalized = math.max(0, math.min(index, _images.length - 1));
    if (_pageIndexNotifier.value != normalized) {
      _pageIndexNotifier.value = normalized;
    }
  }

  Future<void> _persistReaderBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _persistReaderDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _persistReaderString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _updateReaderModeSetting(_ReaderMode? value) async {
    if (value == null) {
      return;
    }
    final changed = _readerMode != value;
    setState(() {
      _readerMode = value;
    });
    await _persistReaderString('reader_reading_mode', value.prefsValue);
    if (changed) {
      _resetZoomImmediately();
      _syncReaderPositionAfterModeChange();
    }
  }

  Future<void> _toggleTapToTurnPageSetting(bool value) async {
    setState(() {
      _tapToTurnPage = value;
    });
    await _persistReaderBool('reader_tap_to_turn_page', value);
  }

  Future<void> _toggleImmersiveModeSetting(bool value) async {
    setState(() {
      _immersiveMode = value;
    });
    await _persistReaderBool('reader_immersive_mode', value);
    await _applyReaderDisplaySettings();
  }

  Future<void> _toggleKeepScreenOnSetting(bool value) async {
    setState(() {
      _keepScreenOn = value;
    });
    await _persistReaderBool('reader_keep_screen_on', value);
    await _applyReaderDisplaySettings();
  }

  Future<void> _toggleCustomBrightnessSetting(bool value) async {
    setState(() {
      _customBrightness = value;
    });
    await _persistReaderBool('reader_custom_brightness', value);
    await _applyReaderDisplaySettings();
  }

  Future<void> _updateBrightnessSetting(double value) async {
    final normalized = math.max(0.0, math.min(value, 1.0));
    setState(() {
      _brightnessValue = normalized;
    });
    await _persistReaderDouble('reader_brightness_value', normalized);
    await _applyReaderDisplaySettings();
  }

  Future<void> _togglePageIndicatorSetting(bool value) async {
    setState(() {
      _pageIndicator = value;
    });
    await _persistReaderBool('reader_page_indicator', value);
  }

  Future<void> _togglePinchToZoomSetting(bool value) async {
    if (!value) {
      _resetZoomImmediately();
    }
    setState(() {
      _pinchToZoom = value;
    });
    await _persistReaderBool('reader_pinch_to_zoom', value);
  }

  Future<void> _toggleLongPressToSaveSetting(bool value) async {
    setState(() {
      _longPressToSave = value;
    });
    await _persistReaderBool('reader_long_press_save', value);
  }

  Future<void> _openChaptersPanel() async {
    if (_chapterPanelLoading) {
      return;
    }
    setState(() {
      _chapterPanelLoading = true;
    });
    try {
      final details =
          _chapterDetailsCache ??
          await HazukiSourceService.instance.loadComicDetails(widget.comicId);
      _chapterDetailsCache ??= details;
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        _SpringBottomSheetRoute(
          builder: (routeContext) {
            final themedData = widget.comicTheme ?? Theme.of(routeContext);
            return Theme(
              data: themedData,
              child: _ChaptersPanelSheet(
                details: details,
                onDownloadConfirm: (_) {
                  Navigator.of(routeContext).pop();
                },
                onChapterTap: (epId, chapterTitle, index) {
                  unawaited(
                    _handleChapterSelectedFromPanel(
                      routeContext,
                      epId,
                      chapterTitle,
                      index,
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).readerChapterLoadFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _chapterPanelLoading = false;
        });
      }
    }
  }

  Future<void> _handleChapterSelectedFromPanel(
    BuildContext routeContext,
    String epId,
    String chapterTitle,
    int index,
  ) async {
    Navigator.of(routeContext).pop();
    if (epId == widget.epId) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          title: widget.title,
          chapterTitle: chapterTitle,
          comicId: widget.comicId,
          epId: epId,
          chapterIndex: index,
          images: const [],
          comicTheme: widget.comicTheme,
        ),
      ),
    );
  }

  void _syncReaderPositionAfterModeChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _images.isEmpty) {
        return;
      }
      final target = math.max(0, math.min(_currentPageIndex, _images.length - 1));
      _setDisplayedPageIndex(target);
      if (_readerMode == _ReaderMode.rightToLeft) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(target);
        }
      } else {
        unawaited(_scrollToListReaderPage(target, animate: false));
      }
    });
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
      final sourceService = HazukiSourceService.instance;
      Uint8List bytes;
      String outputExtension = 'png';

      if (sourceService.isLocalImagePath(imageUrl)) {
        final file = File(sourceService.normalizeLocalImagePath(imageUrl));
        bytes = await file.readAsBytes();
        final localExtMatch = RegExp(
          r'\.([a-zA-Z0-9]+)$',
          caseSensitive: false,
        ).firstMatch(file.path);
        outputExtension =
            localExtMatch?.group(1)?.toLowerCase().trim().isNotEmpty == true
            ? localExtMatch!.group(1)!.toLowerCase()
            : 'jpg';
      } else {
        final prepared = await sourceService.prepareChapterImageData(
          imageUrl,
          comicId: widget.comicId,
          epId: widget.epId,
        );
        bytes = prepared.bytes;
        outputExtension = prepared.extension;
      }

      final uri = Uri.tryParse(imageUrl);
      final lastSegment = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : '';
      final defaultName =
          'hazuki_${DateTime.now().millisecondsSinceEpoch}.$outputExtension';
      final fileName = lastSegment.isEmpty
          ? defaultName
          : lastSegment.split('?').first;
      final saveName = fileName.contains('.')
          ? fileName.replaceAll(
              RegExp(r'\.([a-zA-Z0-9]+)$', caseSensitive: false),
              '.$outputExtension',
            )
          : '$fileName.$outputExtension';
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
        _zoomController.value = Matrix4.identity();
        _imageAspectRatioCache.clear();
        _images = images.where((e) => e.trim().isNotEmpty).toList();
        _itemKeys.clear();
        _itemKeys.addAll(List.generate(_images.length, (_) => GlobalKey()));
        _rebuildImageIndexMap();
        _loadingImages = false;
        _loadImagesError = null;
        _currentPageIndex = 0;
        _isZoomed = false;
        _zoomInteracting = false;
        _activePointerCount = 0;
      });
      _setDisplayedPageIndex(0);
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
    if (!_scrollController.hasClients || _images.isEmpty) {
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
    }
    _setDisplayedPageIndex(normalizedIndex);
    if (!_noImageModeEnabled) {
      _prefetchAround(normalizedIndex);
      unawaited(_prefetchAheadFrom(normalizedIndex));
    }
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

    await _acquireUnscramblePermit();
    try {
      final prepared = await sourceService.prepareChapterImageData(
        url,
        comicId: widget.comicId,
        epId: widget.epId,
      );
      await _rememberAspectRatioFromBytes(url, prepared.bytes);
      return MemoryImage(prepared.bytes);
    } finally {
      _releaseUnscramblePermit();
    }
  }

  Widget _buildReaderListItem(int index) {
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
        Image(
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
  }

  Widget _buildReaderListView() {
    return ListView.builder(
      key: ValueKey('${widget.comicId}-${widget.epId}'),
      padding: EdgeInsets.zero,
      itemCount: _images.length,
      controller: _scrollController,
      physics: _zoomGestureActive
          ? const NeverScrollableScrollPhysics()
          : const _ReaderScrollPhysics(),
      itemBuilder: (context, index) => _buildReaderListItem(index),
    );
  }

  Widget _buildReaderPageView() {
    return PageView.builder(
      key: ValueKey('${widget.comicId}-${widget.epId}-rtl'),
      controller: _pageController,
      reverse: false,
      allowImplicitScrolling: true,
      itemCount: _images.length,
      physics: _pageNavigationLocked
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: (index) {
        if (_pageNavigationLocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                !_pageController.hasClients ||
                _currentPageIndex == index) {
              return;
            }
            _pageController.jumpToPage(_currentPageIndex);
          });
          return;
        }
        final pageChanged = _currentPageIndex != index;
        final zoomWasActive = _isZoomed;
        _resetZoomImmediately();
        if (pageChanged || zoomWasActive) {
          setState(() {
            _currentPageIndex = index;
          });
        }
        _setDisplayedPageIndex(index);
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

  Future<void> _scrollToListReaderPage(
    int index, {
    bool animate = true,
  }) async {
    if (!_scrollController.hasClients || _images.isEmpty) {
      return;
    }
    final target = math.max(0, math.min(index, _images.length - 1));
    final visibleContext =
        target < _itemKeys.length ? _itemKeys[target].currentContext : null;
    if (visibleContext != null) {
      await Scrollable.ensureVisible(
        visibleContext,
        duration: animate ? const Duration(milliseconds: 360) : Duration.zero,
        curve: Curves.easeOutCubic,
        alignment: 0,
      );
      return;
    }

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final ratio = _images.length <= 1 ? 0.0 : target / (_images.length - 1);
    final estimatedOffset = math.max(
      0.0,
      math.min(maxScrollExtent * ratio, maxScrollExtent),
    );
    if (animate) {
      await _scrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(estimatedOffset);
    }

    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final exactContext =
          target < _itemKeys.length ? _itemKeys[target].currentContext : null;
      if (exactContext != null) {
        Scrollable.ensureVisible(
          exactContext,
          duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
          curve: Curves.easeOutCubic,
          alignment: 0,
        );
      }
    });
  }

  Future<void> _goToReaderPage(int index) async {
    if (_images.isEmpty) {
      return;
    }
    final target = math.max(0, math.min(index, _images.length - 1));
    _setDisplayedPageIndex(target);
    if (_readerMode == _ReaderMode.rightToLeft) {
      if (!_pageController.hasClients || target == _currentPageIndex) {
        return;
      }
      _resetZoomImmediately();
      await _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _scrollToListReaderPage(target);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final tapPagingEnabled =
            _readerMode == _ReaderMode.rightToLeft && _tapToTurnPage;
        final leftTriggerWidth = constraints.maxWidth * 0.25;
        final rightTriggerStart = constraints.maxWidth * 0.75;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            if (_activePointerCount > 1) {
              return;
            }
            final dx = details.localPosition.dx;
            final isCenterTap = dx > leftTriggerWidth && dx < rightTriggerStart;
            if (tapPagingEnabled && !_pageNavigationLocked) {
              if (dx <= leftTriggerWidth) {
                unawaited(_goToPreviousPage());
                return;
              }
              if (dx >= rightTriggerStart) {
                unawaited(_goToNextPage());
                return;
              }
            }
            if (isCenterTap) {
              _toggleControlsVisibility();
            }
          },
          child: child,
        );
      },
    );
  }

  Widget _buildReaderSettingsDrawer() {
    final strings = l10n(context);
    final theme = Theme.of(context);
    final sliderActiveColor = theme.colorScheme.primary;
    final sliderInactiveColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.24,
    );
    final brightnessText = (_brightnessValue * 100).round().toString();
    final drawerWidth = math.min(MediaQuery.sizeOf(context).width * 0.88, 360.0);

    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.readingSettingsTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (drawerContext) {
                      return IconButton(
                        tooltip: strings.commonClose,
                        onPressed: () => Navigator.of(drawerContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.chrome_reader_mode_outlined),
              title: Text(strings.readingModeTitle),
              subtitle: Text(strings.readingModeSubtitle),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<_ReaderMode>(
                  value: _readerMode,
                  borderRadius: BorderRadius.circular(18),
                  onChanged: _updateReaderModeSetting,
                  items: [
                    DropdownMenuItem(
                      value: _ReaderMode.topToBottom,
                      child: Text(strings.readingModeTopToBottom),
                    ),
                    DropdownMenuItem(
                      value: _ReaderMode.rightToLeft,
                      child: Text(strings.readingModeRightToLeft),
                    ),
                  ],
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.touch_app_outlined),
              title: Text(strings.readingTapToTurnPageTitle),
              subtitle: Text(strings.readingTapToTurnPageSubtitle),
              value: _tapToTurnPage,
              onChanged: _readerMode == _ReaderMode.rightToLeft
                  ? _toggleTapToTurnPageSetting
                  : null,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fullscreen_outlined),
              title: Text(strings.readingImmersiveModeTitle),
              subtitle: Text(strings.readingImmersiveModeSubtitle),
              value: _immersiveMode,
              onChanged: _toggleImmersiveModeSetting,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.screen_lock_portrait_outlined),
              title: Text(strings.readingKeepScreenOnTitle),
              subtitle: Text(strings.readingKeepScreenOnSubtitle),
              value: _keepScreenOn,
              onChanged: _toggleKeepScreenOnSetting,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.brightness_medium_outlined),
              title: Text(strings.readingCustomBrightnessTitle),
              subtitle: Text(strings.readingCustomBrightnessSubtitle),
              value: _customBrightness,
              onChanged: _toggleCustomBrightnessSetting,
            ),
            ListTile(
              leading: Icon(
                Icons.wb_sunny_outlined,
                color: _customBrightness
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              title: Text(
                strings.readingBrightnessLabel(brightnessText),
                style: TextStyle(
                  color: _customBrightness
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
              subtitle: Slider(
                value: _brightnessValue,
                min: 0,
                max: 1,
                divisions: 100,
                onChanged: _customBrightness ? _updateBrightnessSetting : null,
                activeColor: sliderActiveColor,
                inactiveColor: sliderInactiveColor,
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.format_list_numbered_outlined),
              title: Text(strings.readingPageIndicatorTitle),
              subtitle: Text(strings.readingPageIndicatorSubtitle),
              value: _pageIndicator,
              onChanged: _togglePageIndicatorSetting,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.zoom_in_outlined),
              title: Text(strings.readingPinchToZoomTitle),
              subtitle: Text(strings.readingPinchToZoomSubtitle),
              value: _pinchToZoom,
              onChanged: _togglePinchToZoomSetting,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.save_alt_outlined),
              title: Text(strings.readingLongPressSaveTitle),
              subtitle: Text(strings.readingLongPressSaveSubtitle),
              value: _longPressToSave,
              onChanged: _toggleLongPressToSaveSetting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderTopControls(ThemeData readerTheme) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: IgnorePointer(
          ignoring: !_controlsVisible,
          child: AnimatedSlide(
            offset: _controlsVisible ? Offset.zero : const Offset(0, -0.32),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: AnimatedScale(
              scale: _controlsVisible ? 1.0 : 0.96,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.64),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: readerTheme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n(context).readingSettingsTitle,
                        onPressed: _openReaderSettingsDrawer,
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
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
    );
  }

  Widget _buildReaderPageIndicator(ThemeData readerTheme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: IgnorePointer(
          ignoring: true,
          child: AnimatedSlide(
            offset: _controlsVisible ? const Offset(0, 0.24) : Offset.zero,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ValueListenableBuilder<int>(
                  valueListenable: _pageIndexNotifier,
                  builder: (context, pageIndex, _) {
                    final strings = l10n(context);
                    final chapter = math.max(1, widget.chapterIndex + 1);
                    final current = math.max(
                      1,
                      math.min(pageIndex + 1, _images.length),
                    );
                    final total = math.max(_images.length, 1);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.64),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        strings.readerPageIndicator(
                          chapter.toString(),
                          current.toString(),
                          total.toString(),
                        ),
                        style: readerTheme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderBottomControls(ThemeData readerTheme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: IgnorePointer(
          ignoring: !_controlsVisible,
          child: AnimatedSlide(
            offset: _controlsVisible ? Offset.zero : const Offset(0, 0.36),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: AnimatedScale(
              scale: _controlsVisible ? 1.0 : 0.96,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: ValueListenableBuilder<int>(
                  valueListenable: _pageIndexNotifier,
                  builder: (context, pageIndex, _) {
                    final maxIndex = math.max(_images.length - 1, 0);
                    final rawSliderValue =
                        _sliderDragging ? _sliderDragValue : pageIndex.toDouble();
                    final sliderValue = math.min(
                      math.max(rawSliderValue, 0.0),
                      maxIndex.toDouble(),
                    );
                    final displayIndex = math.max(
                      0,
                      math.min(
                        _sliderDragging ? sliderValue.round() : pageIndex,
                        maxIndex,
                      ),
                    );
                    final canDrag = _images.length > 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${displayIndex + 1}',
                              textAlign: TextAlign.center,
                              style: readerTheme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white.withValues(
                                  alpha: 0.22,
                                ),
                                thumbColor: readerTheme.colorScheme.primary,
                                overlayColor: readerTheme.colorScheme.primary
                                    .withValues(alpha: 0.18),
                                trackHeight: 3.2,
                              ),
                              child: Slider(
                                min: 0,
                                max: maxIndex.toDouble(),
                                divisions: canDrag ? maxIndex : null,
                                value: sliderValue,
                                onChangeStart: canDrag
                                    ? (value) {
                                        setState(() {
                                          _sliderDragging = true;
                                          _sliderDragValue = value;
                                        });
                                      }
                                    : null,
                                onChanged: canDrag
                                    ? (value) {
                                        setState(() {
                                          _sliderDragging = true;
                                          _sliderDragValue = value;
                                        });
                                      }
                                    : null,
                                onChangeEnd: canDrag
                                    ? (value) {
                                        final target = math.max(
                                          0,
                                          math.min(value.round(), maxIndex),
                                        );
                                        setState(() {
                                          _sliderDragging = false;
                                          _sliderDragValue = target.toDouble();
                                        });
                                        unawaited(_goToReaderPage(target));
                                      }
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${_images.length}',
                              textAlign: TextAlign.center,
                              style: readerTheme.textTheme.labelLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              tooltip: l10n(context).comicDetailChapters,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onPressed: _chapterPanelLoading
                                  ? null
                                  : _openChaptersPanel,
                              icon: _chapterPanelLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.menu_book_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
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
        key: _scaffoldKey,
        backgroundColor: readerBg,
        endDrawerEnableOpenDragGesture: false,
        endDrawer: _buildReaderSettingsDrawer(),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handleReaderPointerDown,
                onPointerUp: _handleReaderPointerEnd,
                onPointerCancel: _handleReaderPointerEnd,
                child: _wrapReaderTapPaging(
                  _readerMode == _ReaderMode.rightToLeft
                      ? _buildReaderPageView()
                      : _buildTopToBottomReaderView(),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildReaderTopControls(readerTheme),
              ),
              if (_pageIndicator)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildReaderPageIndicator(readerTheme),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildReaderBottomControls(readerTheme),
              ),
              if (_pinchToZoom)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  bottom: _controlsVisible ? 104 : 24,
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

/// 阅读器专用滚动物理引擎：
/// - 基于 ClampingScrollPhysics，到顶部/到底部不会越界回弹
/// - 使用默认滑动速度（1000 px/s），避免过大惯性导致快速下滑时冲回顶部
class _ReaderScrollPhysics extends ClampingScrollPhysics {
  const _ReaderScrollPhysics({super.parent});

  @override
  _ReaderScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ReaderScrollPhysics(parent: buildParent(ancestor));
  }
}
