import 'package:hazuki/features/reader/support/reader_input_controller.dart';
import 'package:hazuki/features/reader/support/reader_navigation_prefetch.dart';
import 'package:hazuki/features/reader/support/reader_display_session.dart';
import 'package:hazuki/features/reader/support/reader_view_bindings.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/shared/window/window_title_bar_control.dart';
import 'package:hazuki/features/reader/support/reader_dependencies.dart';
import 'package:hazuki/shared/comments/comments_widget_builder.dart';
import 'package:hazuki/shared/reading/reader_filter_color.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:hazuki/features/reader/support/reader_actions_controller.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_controller.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/support/reader_page_context.dart';
import 'package:hazuki/features/reader/support/reader_save_image_controller.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/features/reader/support/reader_settings_controller.dart';
import 'package:hazuki/shared/reading/reader_source_image_quality_settings.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';
import 'package:hazuki/features/reader/view/reader_image_views.dart';
import 'package:hazuki/features/reader/view/reader_overlay_builders.dart';
import 'package:hazuki/features/reader/view/reader_overlay_host.dart';
import 'package:hazuki/features/reader/view/reader_state_views.dart';
import 'package:hazuki/features/reader/view/reader_windows_shortcuts_dialog.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/shared/ui_flags.dart';
import '../state/reader_scroll_state.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.title,
    required this.chapterTitle,
    required this.comicId,
    required this.epId,
    required this.chapterIndex,
    required this.images,
    required this.dependencies,
    required this.commentsWidgetBuilder,
    this.sourceKey = '',
    this.coverUrl = '',
    this.comicTheme,
    this.onFavoriteRequested,
    this.offlineMode = false,
    this.offlineChapters = const <ReaderOfflineChapterData>[],
  });

  final String title;
  final String chapterTitle;
  final String comicId;
  final String epId;
  final int chapterIndex;
  final List<String> images;
  final ReaderDependencies dependencies;
  final String sourceKey;
  final String coverUrl;
  final ThemeData? comicTheme;
  final Future<void> Function(BuildContext)? onFavoriteRequested;
  final ReaderCommentsWidgetBuilder commentsWidgetBuilder;
  final bool offlineMode;
  final List<ReaderOfflineChapterData> offlineChapters;

  @override
  State<ReaderPage> createState() => _ReaderPageHostState();
}

// Chapter changes stay inside the original route so its return transition and
// navigation result remain intact.
class _ReaderPageHostState extends State<ReaderPage> {
  final _chapterNavigatorKey = GlobalKey<NavigatorState>();
  late ReaderPage _chapter = widget;
  bool _chapterCanHandlePop = false;
  bool _settingsDrawerOpen = false;

  void _switchChapter(ReaderPageContext chapter, {bool animate = true}) {
    _chapter = ReaderPage(
      title: chapter.title,
      chapterTitle: chapter.chapterTitle,
      comicId: chapter.comicId,
      epId: chapter.epId,
      chapterIndex: chapter.chapterIndex,
      images: chapter.images,
      dependencies: widget.dependencies,
      sourceKey: chapter.sourceKey,
      coverUrl: chapter.coverUrl,
      comicTheme: chapter.comicTheme,
      onFavoriteRequested: chapter.onFavoriteRequested,
      commentsWidgetBuilder: chapter.commentsWidgetBuilder,
      offlineMode: chapter.offlineMode,
      offlineChapters: chapter.offlineChapters,
    );
    unawaited(
      _chapterNavigatorKey.currentState!.pushReplacement<void, void>(
        _buildChapterRoute(_chapter, skipEntrance: !animate),
      ),
    );
  }

  Route<void> _buildChapterRoute(
    ReaderPage chapter, {
    bool skipEntrance = false,
  }) {
    return _ReaderChapterRoute(
      skipEntrance: skipEntrance,
      builder: (_) => _ReaderChapterPage(
        page: chapter,
        onChapterChanged: _switchChapter,
        onExitReader: () => Navigator.of(context).maybePop(),
        onSettingsDrawerChanged: (open) {
          if (_settingsDrawerOpen != open) {
            setState(() {
              _settingsDrawerOpen = open;
              if (!open) {
                // Dismissing a popup while the drawer is open reports that the
                // chapter can pop. Removing the drawer's local history entry
                // does not emit another navigation notification.
                _chapterCanHandlePop =
                    _chapterNavigatorKey.currentState?.canPop() ?? false;
              }
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_chapterCanHandlePop && !_settingsDrawerOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_chapterNavigatorKey.currentState!.maybePop(result));
        }
      },
      child: NotificationListener<NavigationNotification>(
        onNotification: (notification) {
          if (_chapterCanHandlePop != notification.canHandlePop) {
            setState(() => _chapterCanHandlePop = notification.canHandlePop);
          }
          return false;
        },
        child: Navigator(
          key: _chapterNavigatorKey,
          onGenerateRoute: (_) =>
              _buildChapterRoute(_chapter, skipEntrance: true),
        ),
      ),
    );
  }
}

// Use Flutter's platform transitions for chapters without replacing the outer
// reader route, which owns the original return animation.
class _ReaderChapterRoute extends MaterialPageRoute<void> {
  _ReaderChapterRoute({required super.builder, required this.skipEntrance});

  final bool skipEntrance;

  @override
  AnimationController createAnimationController() {
    final controller = super.createAnimationController();
    if (skipEntrance) controller.value = 1;
    return controller;
  }
}

class _ReaderChapterPage extends StatefulWidget {
  const _ReaderChapterPage({
    required this.page,
    required this.onChapterChanged,
    required this.onExitReader,
    required this.onSettingsDrawerChanged,
  });

  final ReaderPage page;
  final ReaderChapterChanged onChapterChanged;
  final VoidCallback onExitReader;
  final ValueChanged<bool> onSettingsDrawerChanged;

  @override
  State<_ReaderChapterPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<_ReaderChapterPage>
    with SingleTickerProviderStateMixin {
  static const _readerSettingsStore = ReaderSettingsStore();
  late final _sourceSettings = widget.page.dependencies.sourceSettings;

  ReaderSourceImageQualitySnapshot _sourceImageQuality =
      ReaderSourceImageQualitySnapshot.defaults;

  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TransformationController _zoomController = TransformationController();
  final ReaderScrollState _scrollState = ReaderScrollState();
  final ReaderDiagnosticsState _diagnosticsState = ReaderDiagnosticsState();
  final FocusNode _readerKeyFocusNode = FocusNode();
  final ReaderRuntimeState _runtimeState = ReaderRuntimeState();
  final ReaderImagePipelineState _imagePipelineState =
      ReaderImagePipelineState();
  late final ReaderPageContext _pageContext = ReaderPageContext(
    title: widget.page.title,
    chapterTitle: widget.page.chapterTitle,
    comicId: widget.page.comicId,
    epId: widget.page.epId,
    chapterIndex: widget.page.chapterIndex,
    images: widget.page.images,
    sourceKey: widget.page.sourceKey,
    coverUrl: widget.page.coverUrl,
    comicTheme: widget.page.comicTheme,
    onFavoriteRequested: widget.page.onFavoriteRequested,
    commentsWidgetBuilder: widget.page.commentsWidgetBuilder,
    offlineMode: widget.page.offlineMode,
    offlineChapters: widget.page.offlineChapters,
  );

  late final AnimationController _resetAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final ReaderDisplayBridge _displayBridge = ReaderDisplayBridge(
    onVolumeButtonPressed: _handlePlatformVolumeButtonPressed,
  );
  late final ReaderDisplaySession _displaySession = ReaderDisplaySession(
    controller: ReaderDisplayBridge.controller,
    sessionId: _displayBridge.sessionId,
    readSettings: () => _runtimeState.settings,
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
        comicId: widget.page.comicId,
        epId: widget.page.epId,
        sourceKey: widget.page.sourceKey,
        loadImagesErrorBuilder: (error) =>
            l10n(context).readerChapterLoadFailed('$error'),
        onImageAspectRatioResolved: _handleImageAspectRatioResolved,
        sourceService: widget.page.dependencies.sourceReader,
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
  late final ReaderDiagnosticsController _readerDiagnosticsController =
      ReaderDiagnosticsController(
        runtimeState: _runtimeState,
        imagePipelineState: _imagePipelineState,
        diagnosticsState: _diagnosticsState,
        scrollState: _scrollState,
        scrollController: _scrollController,
        pageController: _pageController,
        zoomController: _zoomController,
        sessionId: () => _displayBridge.sessionId,
        noImageModeEnabled: () => _noImageModeEnabled,
        log: (title, {level = 'info', source = 'reader_ui', content}) =>
            widget.page.dependencies.sourceReader.addReaderLog(
              title: title,
              level: level,
              source: source,
              content: content,
            ),
        comicId: widget.page.comicId,
        epId: widget.page.epId,
        chapterTitle: widget.page.chapterTitle,
        chapterIndex: widget.page.chapterIndex,
      );
  late final ReaderNavigationPrefetch _navigationPrefetch =
      ReaderNavigationPrefetch(
        noImageModeEnabled: () => _noImageModeEnabled,
        prefetchAround: _imagePipelineController.prefetchAround,
        requestPrefetchAhead: _imagePipelineController.requestPrefetchAhead,
      );
  late final ReaderNavigationController _navigationController =
      ReaderNavigationController(
        runtimeState: _runtimeState,
        diagnosticsState: _diagnosticsState,
        scrollState: _scrollState,
        scrollController: _scrollController,
        pageController: _pageController,
        isMounted: () => mounted,
        updateState: _updateReaderState,
        logEvent: _logReaderEvent,
        logPayload: _readerLogPayload,
        logVisiblePageChange: _logVisiblePageChange,
        resetZoomImmediately: _readerZoomController.resetZoomImmediately,
        onPageTargetChanged: _navigationPrefetch.onPageTargetChanged,
        toggleControlsVisibility: _toggleControlsVisibility,
      );
  late final ReaderSessionController _sessionController =
      ReaderSessionController(
        viewBindings: ReaderViewBindings(
          scrollController: _scrollController,
          pageController: _pageController,
          focusNode: _readerKeyFocusNode,
          zoomController: _zoomController,
          onNoImageModeChanged:
              _imagePipelineController.handleNoImageModeChanged,
          onScrollPositionChanged:
              _navigationController.handleScrollPositionChanged,
          onZoomChanged: _readerZoomController.onZoomChanged,
          noImageMode: hazukiNoImageModeNotifier,
        ),
        runtimeState: _runtimeState,
        displayBridge: _displayBridge,
        displaySession: _displaySession,
        settingsStore: _readerSettingsStore,
        applyInitialImages: _imagePipelineController.applyInitialImages,
        loadChapterImages: _imagePipelineController.loadChapterImages,
        isMounted: () => mounted,
        updateState: _updateReaderState,
        logEvent: _logReaderEvent,
        logPayload: _readerLogPayload,
        comicId: widget.page.comicId,
        epId: widget.page.epId,
        sourceKey: widget.page.sourceKey,
        chapterTitle: widget.page.chapterTitle,
        chapterIndex: widget.page.chapterIndex,
        widgetImages: widget.page.images,
        readingProgressService: widget.page.dependencies.readingProgressService,
        offlineMode: widget.page.offlineMode,
      );
  late final ReaderSettingsController _settingsController =
      ReaderSettingsController(
        runtimeState: _runtimeState,
        settingsStore: _readerSettingsStore,
        syncPositionToImageIndex:
            _navigationController.syncPositionToImageIndex,
        syncPositionAfterPinchToggle:
            _navigationController.syncPositionAfterPinchToggle,
        displaySession: _displaySession,
        resetZoomImmediately: _readerZoomController.resetZoomImmediately,
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
        sourceReader: widget.page.dependencies.sourceReader,
        pageContext: _pageContext,
        onChapterChanged: widget.onChapterChanged,
        downloader: widget.page.dependencies.downloader,
      );
  late final ReaderSaveImageController _saveImageController =
      ReaderSaveImageController(
        context: () => context,
        resolveReaderTheme: _resolveReaderTheme,
        sourceReader: widget.page.dependencies.sourceReader,
        isMounted: () => mounted,
        logEvent: _logReaderEvent,
        logPayload: _readerLogPayload,
        comicId: widget.page.comicId,
        epId: widget.page.epId,
        sourceKey: _pageContext.sourceKey,
      );

  WindowTitleBarControl? _windowsTitleBarController;

  bool get _noImageModeEnabled => hazukiNoImageModeNotifier.value;

  ReaderImageViews get _imageViews => ReaderImageViews(
    context: context,
    comicId: widget.page.comicId,
    epId: widget.page.epId,
    comicTheme: widget.page.comicTheme,
    runtimeState: _runtimeState,
    imagePipelineState: _imagePipelineState,
    zoomController: _zoomController,
    imagePipelineController: _imagePipelineController,
    navigationController: _navigationController,
    scrollController: _scrollController,
    pageController: _pageController,
    readerZoomController: _readerZoomController,
    enableInteractiveScaling: _inputState.enableInteractiveScaling,
    blockPageScrolling: _inputState.blockPageScrolling,
    wrapImageWidget: _wrapImageWidget,
    noImageModeEnabled: _noImageModeEnabled,
  );

  void _updateReaderState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  ReaderInputState get _inputState => ReaderInputState(
    readerMode: _runtimeState.readerMode,
    volumeButtonTurnPage: _runtimeState.volumeButtonTurnPage,
    isWindows: Platform.isWindows,
    isAltPressed: HardwareKeyboard.instance.isAltPressed,
    isControlPressed: HardwareKeyboard.instance.isControlPressed,
    activePointerCount: _runtimeState.activePointerCount,
  );

  late final _inputController = ReaderInputController(
    readState: () => _inputState,
    previousPage: (trigger) =>
        _navigationController.goPreviousPage(trigger: trigger),
    nextPage: (trigger) => _navigationController.goNextPage(trigger: trigger),
    jumpToAdjacentChapter: _actionsController.jumpToAdjacentChapter,
    onScalingInputChanged: () => _updateReaderState(() {}),
  );

  Future<void> _openFavoriteDialogAndRestoreFocus() async {
    await _actionsController.openFavoriteDialog();
    if (!mounted) {
      return;
    }
    _readerKeyFocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _readerKeyFocusNode.requestFocus();
      }
    });
  }

  Future<void> _showWindowsShortcutsGuide() async {
    if (!Platform.isWindows || !mounted) {
      return;
    }
    await showReaderWindowsShortcutsDialog(
      context,
      theme: _resolveReaderTheme(context),
    );
    if (mounted) {
      _readerKeyFocusNode.requestFocus();
    }
  }

  Future<void> _showInitialWindowsShortcutsGuideIfNeeded() async {
    if (!Platform.isWindows ||
        await _readerSettingsStore.hasSeenWindowsShortcutsGuide() ||
        !mounted) {
      return;
    }
    await _showWindowsShortcutsGuide();
    await _readerSettingsStore.markWindowsShortcutsGuideSeen();
  }

  @override
  void initState() {
    super.initState();
    _sessionController.initialize();
    _sourceImageQuality = ReaderSourceImageQualitySettings.load(
      _sourceSettings,
      widget.page.sourceKey,
    );
    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_showInitialWindowsShortcutsGuideIfNeeded());
      });
    }
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
        onEndDrawerChanged: widget.onSettingsDrawerChanged,
        endDrawer: _buildReaderSettingsDrawer(readerTheme),
        body: Focus(
          autofocus: true,
          focusNode: _readerKeyFocusNode,
          onKeyEvent: _inputController.handleKeyEvent,
          child: SafeArea(
            top: false,
            bottom: false,
            child: ReaderOverlayHost(
              runtimeState: _runtimeState,
              readerTheme: readerTheme,
              title: widget.page.title,
              chapterIndex: widget.page.chapterIndex,
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
              onFavorite:
                  !widget.page.offlineMode &&
                      widget.page.onFavoriteRequested != null
                  ? () {
                      unawaited(_openFavoriteDialogAndRestoreFocus());
                    }
                  : null,
              onComments: !_actionsController.commentsEnabled
                  ? null
                  : () {
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
    if (_runtimeState.filterEnabled) {
      final filterColor = switch (_runtimeState.filterColor) {
        ReaderFilterColor.yellow => const Color(0xFFFFD54F),
        ReaderFilterColor.black => Colors.black,
      };
      result = Stack(
        fit: StackFit.passthrough,
        children: [
          result,
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: filterColor.withValues(
                  alpha: _runtimeState.filterStrength,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_runtimeState.longPressToSave) {
      result = GestureDetector(
        onLongPress: () => _showSaveImageDialog(url),
        child: result,
      );
    }
    return result;
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
      onFilterEnabledChanged: _settingsController.toggleFilter,
      onFilterColorChanged: _settingsController.updateFilterColor,
      onFilterStrengthChanged: _runtimeState.filterEnabled
          ? _settingsController.updateFilterStrength
          : null,
      onFilterStrengthChangeEnd: _runtimeState.filterEnabled
          ? _settingsController.handleFilterStrengthChangeEnd
          : null,
      sourceImageQuality: _sourceImageQuality,
      onSourceImageQualityChanged: (value) async {
        if (value == null) return;
        final normalized = _sourceImageQuality.normalize(value);
        if (normalized == _sourceImageQuality.value) return;
        setState(() {
          _sourceImageQuality = _sourceImageQuality.copyWith(value: normalized);
        });
        await ReaderSourceImageQualitySettings.updateImageQuality(
          _sourceSettings,
          widget.page.sourceKey,
          normalized,
        );
      },
      onShowWindowsShortcuts: Platform.isWindows
          ? () => unawaited(_showWindowsShortcutsGuide())
          : null,
    );
  }

  void _toggleControlsVisibility() {
    final nextVisible = !_runtimeState.controlsVisible;
    _updateReaderState(() {
      _runtimeState.setControlsVisible(nextVisible);
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

  void _handleImageAspectRatioResolved({
    required int imageIndex,
    double? previousAspectRatio,
    required double resolvedAspectRatio,
  }) {
    _navigationController.handleListImageAspectRatioResolved(
      imageIndex: imageIndex,
      previousAspectRatio: previousAspectRatio,
      resolvedAspectRatio: resolvedAspectRatio,
    );
  }

  void _openReaderSettingsDrawer() {
    _logReaderEvent('Reader settings drawer opened', source: 'reader_settings');
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _handleBackPressed() {
    _logReaderEvent('Reader back pressed', source: 'reader_navigation');
    widget.onExitReader();
  }

  Future<void> _showSaveImageDialog(String imageUrl) {
    return _saveImageController.showSaveImageDialog(imageUrl);
  }

  Map<String, dynamic> _readerLogPayload([Map<String, dynamic>? extra]) {
    return _readerDiagnosticsController.buildLogPayload(extra);
  }

  void _logReaderEvent(
    String title, {
    String level = 'info',
    String source = 'reader_ui',
    Object? content,
  }) {
    _readerDiagnosticsController.logEvent(
      title,
      level: level,
      source: source,
      content: content ?? _readerLogPayload(),
    );
  }

  void _logVisiblePageChange({required int index, required String trigger}) {
    _readerDiagnosticsController.logVisiblePageChange(
      index: index,
      trigger: trigger,
    );
  }
}
