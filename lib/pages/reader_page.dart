import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app.dart';
import '../l10n/l10n.dart';
import '../models/hazuki_models.dart';
import '../services/hazuki_source_service.dart';
import '../widgets/widgets.dart';
import 'comic_detail_page.dart';
import 'reader/reader.dart';
import 'reader/reader_diagnostics_support.dart';
import 'reader/reader_overlay_controls.dart';
import 'reader/reader_settings_drawer_content.dart';
import 'reader/reader_settings_store.dart';
import 'reader/reader_state_views.dart';

part 'reader/reader_diagnostics_actions.dart';
part 'reader/reader_image_pipeline.dart';
part 'reader/reader_lifecycle_actions.dart';
part 'reader/reader_list_item_builder.dart';
part 'reader/reader_media_actions.dart';
part 'reader/reader_navigation_actions.dart';
part 'reader/reader_settings_actions.dart';
part 'reader/reader_shell_widgets.dart';
part 'reader/reader_zoom_actions.dart';

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
  static const _readerDisplayChannel = MethodChannel(
    'hazuki.comics/reader_display',
  );
  static const _readerSettingsStore = ReaderSettingsStore();
  static const _readerDisplayController = ReaderDisplayController(
    _readerDisplayChannel,
  );
  static bool _readerDisplayMethodHandlerRegistered = false;
  static _ReaderPageState? _activeReaderPageState;

  static const int _maxUnscrambleConcurrency = 5;
  static const int _prefetchAroundCount = 10;
  static const int _prefetchAheadMemoryCount = 6;
  static const int _providerKeepBehindCount = 12;
  static const int _providerKeepAheadCount = 24;
  static const double _defaultPlaceholderAspectRatio = 0.72;
  static const double _readerListCacheExtentViewportMultiplier = 3.0;
  static const double _readerListCacheExtentMin = 1600;
  static const double _readerListCacheExtentMax = 5200;
  static const double _unexpectedTopOffsetThreshold = 240;
  static const double _topEdgeOffsetEpsilon = 8;

  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, ImageProvider> _providerCache = <String, ImageProvider>{};
  final Map<String, Future<ImageProvider>> _providerFutureCache =
      <String, Future<ImageProvider>>{};
  final Map<String, double> _imageAspectRatioCache = <String, double>{};
  final List<Completer<void>> _decodeWaiters = <Completer<void>>[];
  final Map<String, int> _imageIndexMap = <String, int>{};
  final ValueNotifier<int> _pageIndexNotifier = ValueNotifier<int>(0);
  final List<GlobalKey> _itemKeys = <GlobalKey>[];
  final String _readerSessionId = DateTime.now().microsecondsSinceEpoch
      .toString();
  final TransformationController _zoomController = TransformationController();
  final ReaderDiagnosticsState _diagnosticsState = ReaderDiagnosticsState();
  final FocusNode _readerKeyFocusNode = FocusNode();
  final Set<String> _retryingImageUrls = <String>{};

  int _activeUnscrambleTasks = 0;
  bool _prefetchAheadRunning = false;
  int? _queuedPrefetchAheadIndex;
  int _currentPageIndex = 0;
  bool _controlsVisible = false;
  bool _sliderDragging = false;
  double _sliderDragValue = 0;
  int? _lastSliderHapticPageIndex;
  List<String> _images = const [];
  bool _loadingImages = true;
  String? _loadImagesError;
  ComicDetailsData? _chapterDetailsCache;
  bool _chapterPanelLoading = false;
  bool _immersiveMode = ReaderSettingsStore.defaultImmersiveMode;
  bool _keepScreenOn = ReaderSettingsStore.defaultKeepScreenOn;
  bool _customBrightness = ReaderSettingsStore.defaultCustomBrightness;
  double _brightnessValue = ReaderSettingsStore.defaultBrightnessValue;
  ReaderMode _readerMode = ReaderSettingsStore.defaultReaderMode;
  bool _doublePageMode = ReaderSettingsStore.defaultDoublePageMode;
  bool _tapToTurnPage = ReaderSettingsStore.defaultTapToTurnPage;
  bool _pageIndicator = ReaderSettingsStore.defaultPageIndicator;
  bool _pinchToZoom = ReaderSettingsStore.defaultPinchToZoom;
  bool _longPressToSave = ReaderSettingsStore.defaultLongPressToSave;
  bool _volumeButtonTurnPage = ReaderSettingsStore.defaultVolumeButtonTurnPage;
  bool _isZoomed = false;
  bool _zoomInteracting = false;
  int _activePointerCount = 0;
  late final AnimationController _resetAnimController;

  bool get _noImageModeEnabled => hazukiNoImageModeNotifier.value;

  bool get _zoomGestureActive =>
      _pinchToZoom &&
      (_isZoomed || _zoomInteracting || _activePointerCount > 1);

  bool get _pageNavigationLocked =>
      _pinchToZoom &&
      (_zoomInteracting || _isZoomed || _activePointerCount > 1);

  int get _readerSpreadSize => _doublePageMode ? 2 : 1;

  int get _readerSpreadCount {
    if (_images.isEmpty) {
      return 0;
    }
    return (_images.length + _readerSpreadSize - 1) ~/ _readerSpreadSize;
  }

  int _normalizeSpreadIndex(int index) {
    if (_readerSpreadCount <= 0) {
      return 0;
    }
    return math.max(0, math.min(index, _readerSpreadCount - 1));
  }

  int _spreadStartIndex(int spreadIndex) {
    if (_images.isEmpty) {
      return 0;
    }
    return _normalizeSpreadIndex(spreadIndex) * _readerSpreadSize;
  }

  List<int> _spreadImageIndices(int spreadIndex) {
    if (_images.isEmpty) {
      return const <int>[];
    }
    final start = _spreadStartIndex(spreadIndex);
    final end = math.min(start + _readerSpreadSize, _images.length);
    return List<int>.generate(end - start, (offset) => start + offset);
  }

  void _rebuildSpreadItemKeys() {
    _itemKeys
      ..clear()
      ..addAll(List.generate(_readerSpreadCount, (_) => GlobalKey()));
  }

  void _updateReaderState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  ThemeData _resolveReaderTheme([BuildContext? buildContext]) {
    final targetContext = buildContext ?? context;
    return widget.comicTheme ?? Theme.of(targetContext);
  }

  Color _resolveReaderSurfaceColor([BuildContext? buildContext]) {
    return _resolveReaderTheme(buildContext).colorScheme.surface;
  }

  Color _resolveReaderPlaceholderColor([BuildContext? buildContext]) {
    return _resolveReaderTheme(
      buildContext,
    ).colorScheme.surfaceContainerHighest;
  }

  void _maybeTriggerSliderHaptic(double value) {
    final targetIndex = math.max(
      0,
      math.min(value.round(), _readerSpreadCount - 1),
    );
    if (_lastSliderHapticPageIndex == targetIndex) {
      return;
    }
    _lastSliderHapticPageIndex = targetIndex;
    unawaited(HapticFeedback.selectionClick());
  }

  void _attachReaderDisplayChannelHandler() {
    _activeReaderPageState = this;
    if (_readerDisplayMethodHandlerRegistered) {
      return;
    }
    _readerDisplayChannel.setMethodCallHandler(_handleReaderDisplayMethodCall);
    _readerDisplayMethodHandlerRegistered = true;
  }

  void _detachReaderDisplayChannelHandler() {
    if (identical(_activeReaderPageState, this)) {
      _activeReaderPageState = null;
    }
  }

  static Future<dynamic> _handleReaderDisplayMethodCall(MethodCall call) async {
    if (call.method != 'onVolumeButtonPressed') {
      return null;
    }
    final arguments = call.arguments;
    final direction = arguments is Map<Object?, Object?>
        ? arguments['direction'] as String?
        : null;
    final sessionId = arguments is Map<Object?, Object?>
        ? arguments['sessionId'] as String?
        : null;
    final activeReaderPageState = _activeReaderPageState;
    if (activeReaderPageState == null ||
        !activeReaderPageState.mounted ||
        sessionId != activeReaderPageState._readerSessionId) {
      return null;
    }
    await activeReaderPageState._handlePlatformVolumeButtonPressed(direction);
    return null;
  }

  Future<void> _handlePlatformVolumeButtonPressed(String? direction) async {
    if (!_volumeButtonTurnPage) {
      return;
    }
    if (direction == 'up') {
      await _goToPreviousPage(trigger: 'hardware_volume_up');
      return;
    }
    if (direction == 'down') {
      await _goToNextPage(trigger: 'hardware_volume_down');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeReaderSession();
  }

  @override
  void dispose() {
    _disposeReaderSession();
    super.dispose();
  }

  bool _handleReaderScrollNotification(ScrollNotification notification) {
    if (_readerMode != ReaderMode.topToBottom ||
        notification.depth != 0 ||
        _images.isEmpty) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _diagnosticsState.listUserScrollInProgress =
          notification.dragDetails != null;
    } else if (notification is ScrollEndNotification) {
      _diagnosticsState.listUserScrollInProgress = false;
    } else if (notification is OverscrollNotification) {
      final previousPixels = _diagnosticsState.lastObservedListPixels;
      _logListPositionSnapshot(
        'Reader list overscrolled',
        trigger: notification.overscroll < 0
            ? 'overscroll_top'
            : 'overscroll_bottom',
        previousPixels: previousPixels,
        level: 'warning',
        extra: {
          'notificationType': notification.runtimeType.toString(),
          'depth': notification.depth,
          'overscroll': _normalizeLogDouble(notification.overscroll),
          'velocity': _normalizeLogDouble(notification.velocity),
        },
      );
    }
    return false;
  }

  void _setDisplayedPageIndex(int index) {
    if (_readerSpreadCount <= 0) {
      if (_pageIndexNotifier.value != 0) {
        _pageIndexNotifier.value = 0;
      }
      return;
    }
    final normalized = _normalizeSpreadIndex(index);
    if (_pageIndexNotifier.value != normalized) {
      _pageIndexNotifier.value = normalized;
    }
  }

  @override
  Widget build(BuildContext context) {
    final readerTheme = _resolveReaderTheme(context);

    if (_loadingImages) {
      return ReaderLoadingStateView(theme: readerTheme);
    }

    if (_loadImagesError != null) {
      return ReaderErrorStateView(
        theme: readerTheme,
        message: _loadImagesError!,
        retryLabel: l10n(context).commonRetry,
        onRetry: () {
          setState(() {
            _loadingImages = true;
            _loadImagesError = null;
          });
          unawaited(_loadChapterImages(trigger: 'retry_after_error'));
        },
      );
    }

    if (_images.isEmpty) {
      return ReaderEmptyStateView(
        theme: readerTheme,
        message: l10n(context).readerCurrentChapterNoImages,
      );
    }

    return AnimatedTheme(
      data: readerTheme,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: readerTheme.colorScheme.surface,
        endDrawerEnableOpenDragGesture: false,
        endDrawer: _buildReaderSettingsDrawer(readerTheme),
        body: Focus(
          autofocus: true,
          focusNode: _readerKeyFocusNode,
          onKeyEvent: _handleReaderKeyEvent,
          child: SafeArea(
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
                    _readerMode == ReaderMode.rightToLeft
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildReaderChapterJumpOverlay(),
                ),
                if (_pinchToZoom) _buildReaderZoomResetOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
