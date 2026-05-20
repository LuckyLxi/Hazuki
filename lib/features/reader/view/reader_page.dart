import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/app/windows/windows_title_bar_controller.dart';
import 'package:hazuki/features/reader/reader.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';
import 'package:hazuki/features/reader/support/reader_actions_controller.dart';
import 'package:hazuki/features/reader/support/reader_callbacks.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/support/reader_page_context.dart';
import 'package:hazuki/features/reader/support/reader_save_image_controller.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/features/reader/support/reader_settings_controller.dart';
import 'package:hazuki/features/reader/support/reader_source_image_quality_settings.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';
import 'package:hazuki/features/reader/view/reader_image_views.dart';
import 'package:hazuki/features/reader/view/reader_overlay_builders.dart';
import 'package:hazuki/features/reader/view/reader_overlay_host.dart';
import 'package:hazuki/features/reader/view/reader_state_views.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/shared/ui_flags.dart';

typedef CommentsWidgetBuilder = ReaderCommentsWidgetBuilder;

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.title,
    required this.chapterTitle,
    required this.comicId,
    required this.epId,
    required this.chapterIndex,
    required this.images,
    this.sourceKey = '',
    this.comicTheme,
    this.onFavoriteRequested,
    this.commentsWidgetBuilder,
  });

  final String title;
  final String chapterTitle;
  final String comicId;
  final String epId;
  final int chapterIndex;
  final List<String> images;
  final String sourceKey;
  final ThemeData? comicTheme;
  final Future<void> Function(BuildContext)? onFavoriteRequested;
  final CommentsWidgetBuilder? commentsWidgetBuilder;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  static const _readerSettingsStore = ReaderSettingsStore();
  late final HazukiSourceService _sourceService = sl<HazukiSourceService>();

  ReaderSourceImageQualitySnapshot _sourceImageQuality =
      ReaderSourceImageQualitySnapshot.defaults;

  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TransformationController _zoomController = TransformationController();
  final ReaderDiagnosticsState _diagnosticsState = ReaderDiagnosticsState();
  final FocusNode _readerKeyFocusNode = FocusNode();
  final ReaderRuntimeState _runtimeState = ReaderRuntimeState();
  final ReaderImagePipelineState _imagePipelineState =
      ReaderImagePipelineState();
  late final ReaderPageContext _pageContext = ReaderPageContext(
    title: widget.title,
    chapterTitle: widget.chapterTitle,
    comicId: widget.comicId,
    epId: widget.epId,
    chapterIndex: widget.chapterIndex,
    images: widget.images,
    sourceKey: widget.sourceKey,
    comicTheme: widget.comicTheme,
    onFavoriteRequested: widget.onFavoriteRequested,
    commentsWidgetBuilder: widget.commentsWidgetBuilder,
  );

  late final AnimationController _resetAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final ReaderDisplayBridge _displayBridge = ReaderDisplayBridge(
    onVolumeButtonPressed: _handlePlatformVolumeButtonPressed,
  );
  late final ReaderImagePipelineController _imagePipelineController =
      ReaderImagePipelineController(
        runtimeState: _runtimeState,
        pipelineState: _imagePipelineState,
        diagnosticsState: _diagnosticsState,
        zoomController: _zoomController,
        context: () => context,
        isMounted: () => mounted,
        updateState: _updateReaderState,
        logEvent: _logReaderEvent,
        logPayload: _readerLogPayload,
        logVisiblePageChange: _logVisiblePageChange,
        noImageModeEnabled: () => _noImageModeEnabled,
        comicId: widget.comicId,
        epId: widget.epId,
        sourceKey: widget.sourceKey,
        loadImagesErrorBuilder: (error) =>
            l10n(context).readerChapterLoadFailed('$error'),
        sourceService: sl<HazukiSourceService>(),
      );
  late final ReaderZoomController _readerZoomController = ReaderZoomController(
    transformationController: _zoomController,
    resetAnimController: _resetAnimController,
    runtimeState: _runtimeState,
    isMounted: () => mounted,
    updateState: _updateReaderState,
    logEvent: _logReaderEvent,
    logPayload: _readerLogPayload,
  );
  late final ReaderNavigationController _navigationController =
      ReaderNavigationController(
        runtimeState: _runtimeState,
        diagnosticsState: _diagnosticsState,
        scrollController: _scrollController,
        pageController: _pageController,
        isMounted: () => mounted,
        updateState: _updateReaderState,
        logEvent: _logReaderEvent,
        logPayload: _readerLogPayload,
        logVisiblePageChange: _logVisiblePageChange,
        resetZoomImmediately: _readerZoomController.resetZoomImmediately,
        prefetchAround: _imagePipelineController.prefetchAround,
        requestPrefetchAhead: _imagePipelineController.requestPrefetchAhead,
        noImageModeEnabled: () => _noImageModeEnabled,
        toggleControlsVisibility: _toggleControlsVisibility,
      );
  late final ReaderSessionController _sessionController =
      ReaderSessionController(
        runtimeState: _runtimeState,
        displayBridge: _displayBridge,
        settingsStore: _readerSettingsStore,
        scrollController: _scrollController,
        pageController: _pageController,
        readerKeyFocusNode: _readerKeyFocusNode,
        zoomController: _zoomController,
        applyInitialImages: _imagePipelineController.applyInitialImages,
        loadChapterImages: _imagePipelineController.loadChapterImages,
        onNoImageModeChanged: _imagePipelineController.handleNoImageModeChanged,
        isMounted: () => mounted,
        updateState: _updateReaderState,
        logEvent: _logReaderEvent,
        logPayload: _readerLogPayload,
        onScrollPositionChanged:
            _navigationController.handleScrollPositionChanged,
        onZoomChanged: _readerZoomController.onZoomChanged,
        comicId: widget.comicId,
        epId: widget.epId,
        sourceKey: widget.sourceKey,
        chapterTitle: widget.chapterTitle,
        chapterIndex: widget.chapterIndex,
        widgetImages: widget.images,
        sourceService: sl<HazukiSourceService>(),
      );
  late final ReaderSettingsController _settingsController =
      ReaderSettingsController(
        runtimeState: _runtimeState,
        settingsStore: _readerSettingsStore,
        navigationController: _navigationController,
        sessionController: _sessionController,
        zoomController: _readerZoomController,
        updateState: _updateReaderState,
        logEvent: _logReaderEvent,
        logPayload: _readerLogPayload,
      );
  late final ReaderActionsController _actionsController =
      ReaderActionsController(
        context: () => context,
        isMounted: () => mounted,
        updateState: _updateReaderState,
        logEvent: _logReaderEvent,
        logPayload: _readerLogPayload,
        sessionController: _sessionController,
        pageContext: _pageContext,
        buildReplacementPage: _buildReaderPageFromContext,
      );
  late final ReaderSaveImageController _saveImageController =
      ReaderSaveImageController(
        context: () => context,
        resolveReaderTheme: _resolveReaderTheme,
        sessionController: _sessionController,
        isMounted: () => mounted,
        logEvent: _logReaderEvent,
        logPayload: _readerLogPayload,
        comicId: widget.comicId,
        epId: widget.epId,
      );

  HazukiWindowsTitleBarController? _windowsTitleBarController;

  bool get _noImageModeEnabled => hazukiNoImageModeNotifier.value;

  ReaderImageViews get _imageViews => ReaderImageViews(
    context: context,
    comicId: widget.comicId,
    epId: widget.epId,
    comicTheme: widget.comicTheme,
    runtimeState: _runtimeState,
    imagePipelineState: _imagePipelineState,
    zoomController: _zoomController,
    imagePipelineController: _imagePipelineController,
    navigationController: _navigationController,
    scrollController: _scrollController,
    pageController: _pageController,
    readerZoomController: _readerZoomController,
    wrapImageWidget: _wrapImageWidget,
    noImageModeEnabled: _noImageModeEnabled,
  );

  void _updateReaderState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  @override
  void initState() {
    super.initState();
    _sessionController.initialize();
    _sourceImageQuality = ReaderSourceImageQualitySettings.load(_sourceService);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Platform.isWindows) {
      return;
    }
    final nextController = HazukiWindowsTitleBarScope.of(context);
    if (_windowsTitleBarController == nextController) {
      return;
    }
    _windowsTitleBarController?.releaseCustomTitleBarSuppression(this);
    _windowsTitleBarController = nextController..suppressCustomTitleBar(this);
  }

  @override
  void dispose() {
    _windowsTitleBarController?.releaseCustomTitleBarSuppression(this);
    _resetAnimController.dispose();
    _sessionController.dispose();
    _imagePipelineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readerTheme = _resolveReaderTheme(context);

    if (_runtimeState.loadingImages) {
      return ReaderLoadingStateView(theme: readerTheme);
    }

    if (_runtimeState.loadImagesError != null) {
      return ReaderErrorStateView(
        theme: readerTheme,
        message: _runtimeState.loadImagesError!,
        retryLabel: l10n(context).commonRetry,
        onRetry: () {
          setState(() {
            _runtimeState.markLoadingImages();
          });
          unawaited(
            _imagePipelineController.loadChapterImages(
              trigger: 'retry_after_error',
            ),
          );
        },
      );
    }

    if (_runtimeState.images.isEmpty) {
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
          onKeyEvent: _navigationController.handleKeyEvent,
          child: SafeArea(
            top: false,
            bottom: false,
            child: ReaderOverlayHost(
              runtimeState: _runtimeState,
              readerTheme: readerTheme,
              title: widget.title,
              chapterIndex: widget.chapterIndex,
              chapterPanelLoading: _actionsController.chapterPanelLoading,
              updateState: _updateReaderState,
              goToPage: (target) => _navigationController.goToPage(
                target,
                trigger: 'bottom_slider',
              ),
              onBackPressed: _handleBackPressed,
              onOpenSettingsDrawer: _openReaderSettingsDrawer,
              onOpenChaptersPanel: _actionsController.openChaptersPanel,
              onPreviousChapter: () {
                unawaited(_actionsController.jumpToAdjacentChapter(-1));
              },
              onFavorite: widget.onFavoriteRequested != null
                  ? () {
                      unawaited(_actionsController.openFavoriteDialog());
                    }
                  : null,
              onComments: () {
                unawaited(_actionsController.openCommentsSheet());
              },
              onNextChapter: () {
                unawaited(_actionsController.jumpToAdjacentChapter(1));
              },
              onResetZoom: _readerZoomController.resetZoom,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _readerZoomController.handlePointerDown,
                onPointerUp: _readerZoomController.handlePointerEnd,
                onPointerCancel: _readerZoomController.handlePointerEnd,
                child: _wrapReaderTapPaging(
                  _runtimeState.readerMode == ReaderMode.rightToLeft
                      ? _buildReaderPageView()
                      : _buildTopToBottomReaderView(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ThemeData _resolveReaderTheme([BuildContext? buildContext]) {
    return _imageViews.resolveReaderTheme(buildContext);
  }

  Widget _buildReaderPageView() => _imageViews.buildReaderPageView();

  Widget _buildTopToBottomReaderView() {
    return _imageViews.buildTopToBottomReaderView();
  }

  Widget _wrapReaderTapPaging(Widget child) {
    return _imageViews.wrapReaderTapPaging(child);
  }

  Widget _wrapImageWidget(Widget imageWidget, String url) {
    Widget result = imageWidget;
    if (_runtimeState.longPressToSave) {
      result = GestureDetector(
        onLongPress: () => _showSaveImageDialog(url),
        child: result,
      );
    }
    return result;
  }

  Widget _buildReaderPageFromContext(ReaderPageContext pageContext) {
    return ReaderPage(
      title: pageContext.title,
      chapterTitle: pageContext.chapterTitle,
      comicId: pageContext.comicId,
      epId: pageContext.epId,
      chapterIndex: pageContext.chapterIndex,
      images: pageContext.images,
      sourceKey: pageContext.sourceKey,
      comicTheme: pageContext.comicTheme,
      onFavoriteRequested: pageContext.onFavoriteRequested,
      commentsWidgetBuilder: pageContext.commentsWidgetBuilder,
    );
  }

  Widget _buildReaderSettingsDrawer(ThemeData readerTheme) {
    return buildReaderSettingsDrawer(
      context: context,
      readerTheme: readerTheme,
      runtimeState: _runtimeState,
      onReaderModeChanged: _settingsController.updateReaderMode,
      onDoublePageModeChanged: _settingsController.toggleDoublePageMode,
      onTapToTurnPageChanged: _runtimeState.readerMode == ReaderMode.rightToLeft
          ? _settingsController.toggleTapToTurnPage
          : null,
      onVolumeButtonTurnPageChanged:
          _settingsController.toggleVolumeButtonTurnPage,
      onPinchToZoomChanged: _settingsController.togglePinchToZoom,
      onLongPressToSaveChanged: _settingsController.toggleLongPressToSave,
      onImmersiveModeChanged: _settingsController.toggleImmersiveMode,
      onKeepScreenOnChanged: _settingsController.toggleKeepScreenOn,
      onPageIndicatorChanged: _settingsController.togglePageIndicator,
      onCustomBrightnessChanged: _settingsController.toggleCustomBrightness,
      onBrightnessChanged: _runtimeState.customBrightness
          ? _settingsController.updateBrightness
          : null,
      onBrightnessChangeEnd: _runtimeState.customBrightness
          ? _settingsController.handleBrightnessChangeEnd
          : null,
      sourceImageQuality: _sourceImageQuality,
      onCopyMangaImageQualityChanged: (value) async {
        if (value == null) return;
        final normalized =
            ReaderSourceImageQualitySettings.normalizeCopyMangaImageQuality(
              value,
            );
        if (normalized == _sourceImageQuality.copyMangaImageQuality) return;
        setState(() {
          _sourceImageQuality = _sourceImageQuality.copyWith(
            copyMangaImageQuality: normalized,
          );
        });
        await ReaderSourceImageQualitySettings.updateCopyMangaImageQuality(
          _sourceService,
          normalized,
        );
      },
      onPicacgImageQualityChanged: (value) async {
        if (value == null) return;
        final normalized =
            ReaderSourceImageQualitySettings.normalizePicacgImageQuality(value);
        if (normalized == _sourceImageQuality.picacgImageQuality) return;
        setState(() {
          _sourceImageQuality = _sourceImageQuality.copyWith(
            picacgImageQuality: normalized,
          );
        });
        await ReaderSourceImageQualitySettings.updatePicacgImageQuality(
          _sourceService,
          normalized,
        );
      },
    );
  }

  void _toggleControlsVisibility() {
    final nextVisible = !_runtimeState.controlsVisible;
    _updateReaderState(() {
      _runtimeState.controlsVisible = nextVisible;
    });
    _logReaderEvent(
      'Reader controls toggled',
      source: 'reader_ui',
      content: _readerLogPayload({'controlsVisible': nextVisible}),
    );
  }

  Future<void> _handlePlatformVolumeButtonPressed(String? direction) {
    return _navigationController.handlePlatformVolumeButtonPressed(direction);
  }

  void _openReaderSettingsDrawer() {
    _logReaderEvent('Reader settings drawer opened', source: 'reader_settings');
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _handleBackPressed() {
    _logReaderEvent('Reader back pressed', source: 'reader_navigation');
    Navigator.of(context).maybePop();
  }

  Future<void> _showSaveImageDialog(String imageUrl) {
    return _saveImageController.showSaveImageDialog(imageUrl);
  }

  double _normalizeLogDouble(num value) => normalizeReaderLogDouble(value);

  List<Map<String, dynamic>> _captureRenderedItemsAround(int anchorIndex) {
    return captureReaderRenderedItemsAround(
      itemCount: _runtimeState.readerSpreadCount,
      itemKeys: _runtimeState.itemKeys,
      anchorIndex: anchorIndex,
    );
  }

  ReaderDiagnosticsSnapshot _createReaderDiagnosticsSnapshot() {
    final listSnapshot = _scrollController.hasClients
        ? ReaderListDiagnosticsSnapshot(
            pixels: _normalizeLogDouble(_scrollController.position.pixels),
            maxScrollExtent: _normalizeLogDouble(
              _scrollController.position.maxScrollExtent,
            ),
            minScrollExtent: _normalizeLogDouble(
              _scrollController.position.minScrollExtent,
            ),
            viewportDimension: _normalizeLogDouble(
              _scrollController.position.viewportDimension,
            ),
            extentBefore: _normalizeLogDouble(
              _scrollController.position.extentBefore,
            ),
            extentAfter: _normalizeLogDouble(
              _scrollController.position.extentAfter,
            ),
            atEdge: _scrollController.position.atEdge,
            outOfRange: _scrollController.position.outOfRange,
            userDirection: _scrollController.position.userScrollDirection.name,
          )
        : null;
    final pageControllerPage = _pageController.hasClients
        ? _normalizeLogDouble(
            _pageController.page ?? _runtimeState.currentPageIndex.toDouble(),
          )
        : null;
    return ReaderDiagnosticsSnapshot(
      readerSessionId: _displayBridge.sessionId,
      comicId: widget.comicId,
      epId: widget.epId,
      chapterTitle: widget.chapterTitle,
      chapterIndex: widget.chapterIndex,
      readerMode: _runtimeState.readerMode.prefsValue,
      doublePageMode: _runtimeState.doublePageMode,
      currentPageIndex: _runtimeState.currentPageIndex,
      currentPage: _runtimeState.images.isEmpty
          ? 0
          : math.min(
              _runtimeState.currentPageIndex + 1,
              _runtimeState.readerSpreadCount,
            ),
      pageIndicatorIndex: _runtimeState.pageIndexNotifier.value,
      totalPages: _runtimeState.readerSpreadCount,
      controlsVisible: _runtimeState.controlsVisible,
      tapToTurnPage: _runtimeState.tapToTurnPage,
      pageIndicator: _runtimeState.pageIndicator,
      pinchToZoom: _runtimeState.pinchToZoom,
      longPressToSave: _runtimeState.longPressToSave,
      immersiveMode: _runtimeState.immersiveMode,
      keepScreenOn: _runtimeState.keepScreenOn,
      customBrightness: _runtimeState.customBrightness,
      brightnessValue: _runtimeState.brightnessValue,
      loadingImages: _runtimeState.loadingImages,
      loadImagesError: _runtimeState.loadImagesError,
      noImageModeEnabled: _noImageModeEnabled,
      isZoomed: _runtimeState.isZoomed,
      zoomInteracting: _runtimeState.zoomInteracting,
      zoomScale: _normalizeLogDouble(_zoomController.value.getMaxScaleOnAxis()),
      activePointerCount: _runtimeState.activePointerCount,
      providerCacheSize: _imagePipelineState.providerCache.length,
      providerFutureCacheSize: _imagePipelineState.providerFutureCache.length,
      aspectRatioCacheSize: _imagePipelineState.imageAspectRatioCache.length,
      prefetchAheadRunning: _imagePipelineState.prefetchAheadRunning,
      activeUnscrambleTasks: _imagePipelineState.activeUnscrambleTasks,
      listUserScrollInProgress: _diagnosticsState.listUserScrollInProgress,
      activeProgrammaticListScrollReason:
          _diagnosticsState.activeProgrammaticListScrollReason,
      activeProgrammaticListTargetIndex:
          _diagnosticsState.activeProgrammaticListTargetIndex,
      lastCompletedProgrammaticListTargetIndex:
          _diagnosticsState.lastCompletedProgrammaticListTargetIndex,
      lastObservedListPixels: _diagnosticsState.lastObservedListPixels == null
          ? null
          : _normalizeLogDouble(_diagnosticsState.lastObservedListPixels!),
      pageControllerPage: pageControllerPage,
      listSnapshot: listSnapshot,
    );
  }

  Map<String, dynamic> _readerLogPayload([Map<String, dynamic>? extra]) {
    return buildReaderLogPayload(
      snapshot: _createReaderDiagnosticsSnapshot(),
      extra: extra,
    );
  }

  void _logReaderEvent(
    String title, {
    String level = 'info',
    String source = 'reader_ui',
    Object? content,
  }) {
    _sessionController.log(
      title,
      level: level,
      source: source,
      content: content ?? _readerLogPayload(),
    );
  }

  void _logVisiblePageChange({required int index, required String trigger}) {
    if (_runtimeState.images.isEmpty) {
      return;
    }
    final normalizedIndex = math.max(
      0,
      math.min(index, _runtimeState.readerSpreadCount - 1),
    );
    final safeIndex = _runtimeState.normalizeSpreadIndex(normalizedIndex);
    if (_diagnosticsState.lastLoggedVisiblePageIndex == safeIndex) {
      return;
    }
    _diagnosticsState.lastLoggedVisiblePageIndex = safeIndex;
    _logReaderEvent(
      'Reader visible page changed',
      source: 'reader_position',
      content: _readerLogPayload({
        'trigger': trigger,
        'pageIndex': safeIndex,
        'page': safeIndex + 1,
        'visibleImageIndices': _runtimeState.spreadImageIndices(safeIndex),
        if (_runtimeState.readerMode == ReaderMode.topToBottom)
          'nearbyRenderedItems': _captureRenderedItemsAround(safeIndex),
      }),
    );
  }
}
