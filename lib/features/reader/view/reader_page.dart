import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/app/windows_title_bar_controller.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_panels.dart';
import 'package:hazuki/features/reader/reader.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';
import 'package:hazuki/features/reader/view/reader_image_views.dart';
import 'package:hazuki/features/reader/view/reader_overlay_builders.dart';
import 'package:hazuki/features/reader/view/reader_state_views.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';

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
  static const _readerSettingsStore = ReaderSettingsStore();

  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TransformationController _zoomController = TransformationController();
  final ReaderDiagnosticsState _diagnosticsState = ReaderDiagnosticsState();
  final FocusNode _readerKeyFocusNode = FocusNode();
  final ReaderRuntimeState _runtimeState = ReaderRuntimeState();
  final ReaderImagePipelineState _imagePipelineState =
      ReaderImagePipelineState();

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
        loadImagesErrorBuilder: (error) =>
            l10n(context).readerChapterLoadFailed('$error'),
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
        imagePipelineController: _imagePipelineController,
        isMounted: () => mounted,
        updateState: _updateReaderState,
        logEvent: _logReaderEvent,
        logPayload: _readerLogPayload,
        onScrollPositionChanged:
            _navigationController.handleScrollPositionChanged,
        onZoomChanged: _readerZoomController.onZoomChanged,
        comicId: widget.comicId,
        epId: widget.epId,
        chapterTitle: widget.chapterTitle,
        chapterIndex: widget.chapterIndex,
        widgetImages: widget.images,
      );

  ComicDetailsData? _chapterDetailsCache;
  bool _chapterPanelLoading = false;
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
            child: Stack(
              children: [
                Listener(
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
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildReaderTopControls(readerTheme),
                ),
                if (_runtimeState.pageIndicator)
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
                if (_runtimeState.pinchToZoom) _buildReaderZoomResetOverlay(),
              ],
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

  void _maybeTriggerSliderHaptic(double value) {
    maybeTriggerReaderSliderHaptic(runtimeState: _runtimeState, value: value);
  }

  Widget _buildReaderSettingsDrawer(ThemeData readerTheme) {
    return buildReaderSettingsDrawer(
      context: context,
      readerTheme: readerTheme,
      runtimeState: _runtimeState,
      onReaderModeChanged: _updateReaderModeSetting,
      onDoublePageModeChanged: _toggleDoublePageModeSetting,
      onTapToTurnPageChanged: _runtimeState.readerMode == ReaderMode.rightToLeft
          ? _toggleTapToTurnPageSetting
          : null,
      onVolumeButtonTurnPageChanged: _toggleVolumeButtonTurnPageSetting,
      onPinchToZoomChanged: _togglePinchToZoomSetting,
      onLongPressToSaveChanged: _toggleLongPressToSaveSetting,
      onImmersiveModeChanged: _toggleImmersiveModeSetting,
      onKeepScreenOnChanged: _toggleKeepScreenOnSetting,
      onPageIndicatorChanged: _togglePageIndicatorSetting,
      onCustomBrightnessChanged: _toggleCustomBrightnessSetting,
      onBrightnessChanged: _runtimeState.customBrightness
          ? _updateBrightnessSetting
          : null,
      onBrightnessChangeEnd: _runtimeState.customBrightness
          ? _handleBrightnessChangeEnd
          : null,
    );
  }

  Widget _buildReaderTopControls(ThemeData readerTheme) {
    return buildReaderTopControls(
      context: context,
      runtimeState: _runtimeState,
      readerTheme: readerTheme,
      title: widget.title,
      onBackPressed: _handleBackPressed,
      onOpenSettingsDrawer: _openReaderSettingsDrawer,
    );
  }

  Widget _buildReaderPageIndicator(ThemeData readerTheme) {
    return buildReaderPageIndicator(
      runtimeState: _runtimeState,
      readerTheme: readerTheme,
      chapterIndex: widget.chapterIndex,
    );
  }

  Widget _buildReaderBottomControls(ThemeData readerTheme) {
    return buildReaderBottomControls(
      context: context,
      runtimeState: _runtimeState,
      readerTheme: readerTheme,
      chapterPanelLoading: _chapterPanelLoading,
      maybeTriggerSliderHaptic: _maybeTriggerSliderHaptic,
      updateState: _updateReaderState,
      goToPage: (target) =>
          _navigationController.goToPage(target, trigger: 'bottom_slider'),
      onOpenChaptersPanel: _openChaptersPanel,
    );
  }

  Widget _buildReaderChapterJumpOverlay() {
    return buildReaderChapterJumpOverlay(
      context: context,
      runtimeState: _runtimeState,
      onPreviousChapter: () {
        unawaited(_jumpToAdjacentChapter(-1));
      },
      onNextChapter: () {
        unawaited(_jumpToAdjacentChapter(1));
      },
    );
  }

  Widget _buildReaderZoomResetOverlay() {
    return buildReaderZoomResetOverlay(
      context: context,
      runtimeState: _runtimeState,
      onResetZoom: _readerZoomController.resetZoom,
    );
  }

  Future<void> _updateReaderModeSetting(ReaderMode? value) async {
    if (value == null) {
      return;
    }
    final targetImageIndex = _runtimeState.spreadStartIndex(
      _runtimeState.currentPageIndex,
    );
    final previousMode = _runtimeState.readerMode.prefsValue;
    final changed = _runtimeState.readerMode != value;
    _updateReaderState(() {
      _runtimeState.readerMode = value;
    });
    await _readerSettingsStore.saveReaderMode(value);
    _logReaderEvent(
      changed ? 'Reader mode changed' : 'Reader mode reselected',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'reading_mode',
        'previousValue': previousMode,
        'nextValue': value.prefsValue,
      }),
    );
    if (changed) {
      _readerZoomController.resetZoomImmediately(
        reason: 'reading_mode_changed',
      );
      _navigationController.syncPositionToImageIndex(
        targetImageIndex,
        trigger: 'mode_changed_sync',
      );
    }
  }

  Future<void> _toggleDoublePageModeSetting(bool value) async {
    final targetImageIndex = _runtimeState.spreadStartIndex(
      _runtimeState.currentPageIndex,
    );
    final previousValue = _runtimeState.doublePageMode;
    _updateReaderState(() {
      _runtimeState.doublePageMode = value;
      _runtimeState.rebuildSpreadItemKeys();
    });
    await _readerSettingsStore.saveDoublePageMode(value);
    _logReaderEvent(
      previousValue != value
          ? 'Reader double page mode toggled'
          : 'Reader double page mode reselected',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'double_page_mode',
        'previousValue': previousValue,
        'nextValue': value,
      }),
    );
    if (previousValue != value) {
      _readerZoomController.resetZoomImmediately(
        reason: 'double_page_mode_changed',
      );
      _navigationController.syncPositionToImageIndex(
        targetImageIndex,
        trigger: 'double_page_mode_changed_sync',
      );
    }
  }

  Future<void> _toggleTapToTurnPageSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.tapToTurnPage = value;
    });
    await _readerSettingsStore.saveTapToTurnPage(value);
    _logReaderEvent(
      'Reader tap to turn page toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'tap_to_turn_page',
        'value': value,
      }),
    );
  }

  Future<void> _toggleVolumeButtonTurnPageSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.volumeButtonTurnPage = value;
    });
    await _readerSettingsStore.saveVolumeButtonTurnPage(value);
    _logReaderEvent(
      'Reader volume button turn page toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'volume_button_turn_page',
        'value': value,
      }),
    );
    await _sessionController.syncVolumeButtonPagingPlatformState();
  }

  Future<void> _toggleImmersiveModeSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.immersiveMode = value;
    });
    await _readerSettingsStore.saveImmersiveMode(value);
    _logReaderEvent(
      'Reader immersive mode toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'immersive_mode', 'value': value}),
    );
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> _toggleKeepScreenOnSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.keepScreenOn = value;
    });
    await _readerSettingsStore.saveKeepScreenOn(value);
    _logReaderEvent(
      'Reader keep screen on toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'keep_screen_on', 'value': value}),
    );
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> _toggleCustomBrightnessSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.customBrightness = value;
    });
    await _readerSettingsStore.saveCustomBrightness(value);
    _logReaderEvent(
      'Reader custom brightness toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'custom_brightness',
        'value': value,
      }),
    );
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> _updateBrightnessSetting(double value) async {
    final normalized = ReaderSettingsStore.normalizeBrightnessValue(value);
    _updateReaderState(() {
      _runtimeState.brightnessValue = normalized;
    });
    await _readerSettingsStore.saveBrightnessValue(normalized);
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> _togglePageIndicatorSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.pageIndicator = value;
    });
    await _readerSettingsStore.savePageIndicator(value);
    _logReaderEvent(
      'Reader page indicator toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'page_indicator', 'value': value}),
    );
  }

  Future<void> _togglePinchToZoomSetting(bool value) async {
    final previousValue = _runtimeState.pinchToZoom;
    final targetImageIndex = _runtimeState.images.isEmpty
        ? 0
        : _runtimeState.spreadStartIndex(_runtimeState.pageIndexNotifier.value);
    if (!value) {
      _readerZoomController.resetZoomImmediately(
        reason: 'pinch_to_zoom_disabled',
      );
    }
    _updateReaderState(() {
      _runtimeState.pinchToZoom = value;
    });
    await _readerSettingsStore.savePinchToZoom(value);
    _logReaderEvent(
      'Reader pinch to zoom toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'pinch_to_zoom', 'value': value}),
    );
    if (previousValue != value) {
      unawaited(
        _navigationController.syncPositionAfterPinchToggle(targetImageIndex),
      );
    }
  }

  Future<void> _toggleLongPressToSaveSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.longPressToSave = value;
    });
    await _readerSettingsStore.saveLongPressToSave(value);
    _logReaderEvent(
      'Reader long press to save toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'long_press_to_save',
        'value': value,
      }),
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

  Future<void> _openChaptersPanel() async {
    if (_chapterPanelLoading) {
      return;
    }
    final hadCachedChapterDetails = _chapterDetailsCache != null;
    _updateReaderState(() {
      _chapterPanelLoading = true;
    });
    _logReaderEvent(
      'Reader chapters panel requested',
      source: 'reader_navigation',
      content: _readerLogPayload({
        'hadCachedChapterDetails': hadCachedChapterDetails,
      }),
    );
    try {
      final details =
          _chapterDetailsCache ??
          await _sessionController.loadComicDetails(widget.comicId);
      _chapterDetailsCache ??= details;
      if (!mounted) {
        return;
      }
      _logReaderEvent(
        'Reader chapters panel opened',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'hadCachedChapterDetails': hadCachedChapterDetails,
        }),
      );
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        useSafeArea: false,
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 380),
          reverseDuration: Duration(milliseconds: 280),
        ),
        builder: (routeContext) {
          final themedData = widget.comicTheme ?? Theme.of(routeContext);
          return Theme(
            data: themedData,
            child: ChaptersPanelSheet(
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
      );
    } catch (error) {
      _logReaderEvent(
        'Reader chapters panel failed',
        level: 'error',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'hadCachedChapterDetails': hadCachedChapterDetails,
          'error': '$error',
        }),
      );
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).readerChapterLoadFailed('$error'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        _updateReaderState(() {
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
      _logReaderEvent(
        'Reader chapter selection ignored',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'targetEpId': epId,
          'targetChapterTitle': chapterTitle,
          'targetChapterIndex': index,
          'reason': 'already_current_chapter',
        }),
      );
      return;
    }
    _logReaderEvent(
      'Reader chapter selected',
      source: 'reader_navigation',
      content: _readerLogPayload({
        'targetEpId': epId,
        'targetChapterTitle': chapterTitle,
        'targetChapterIndex': index,
      }),
    );
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

  Future<void> _jumpToAdjacentChapter(int offset) async {
    final navigator = Navigator.of(context);
    final strings = l10n(context);
    try {
      final details =
          _chapterDetailsCache ??
          await _sessionController.loadComicDetails(widget.comicId);
      _chapterDetailsCache ??= details;
      final chapterEntries = details.chapters.entries.toList(growable: false);
      if (chapterEntries.isEmpty) {
        return;
      }

      var currentChapterIndex = chapterEntries.indexWhere(
        (entry) => entry.key == widget.epId,
      );
      if (currentChapterIndex < 0) {
        currentChapterIndex = widget.chapterIndex.clamp(
          0,
          chapterEntries.length - 1,
        );
      }
      final targetIndex = currentChapterIndex + offset;

      if (targetIndex < 0) {
        if (mounted) {
          unawaited(showHazukiPrompt(context, strings.readerNoPreviousChapter));
        }
        return;
      }
      if (targetIndex >= chapterEntries.length) {
        if (mounted) {
          unawaited(
            showHazukiPrompt(context, strings.readerAlreadyLastChapter),
          );
        }
        return;
      }

      final targetChapter = chapterEntries[targetIndex];
      _logReaderEvent(
        'Reader adjacent chapter navigation requested',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'offset': offset,
          'fromChapterIndex': currentChapterIndex,
          'targetChapterIndex': targetIndex,
          'targetEpId': targetChapter.key,
          'targetChapterTitle': targetChapter.value,
        }),
      );

      if (!mounted) {
        return;
      }
      await navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReaderPage(
            title: widget.title,
            chapterTitle: targetChapter.value,
            comicId: widget.comicId,
            epId: targetChapter.key,
            chapterIndex: targetIndex,
            images: const [],
            comicTheme: widget.comicTheme,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.readerChapterLoadFailed('$error'),
          isError: true,
        ),
      );
    }
  }

  void _handleBackPressed() {
    _logReaderEvent('Reader back pressed', source: 'reader_navigation');
    Navigator.of(context).maybePop();
  }

  void _handleBrightnessChangeEnd(double value) {
    final normalized = math.max(0.0, math.min(value, 1.0));
    _logReaderEvent(
      'Reader brightness adjusted',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'brightness',
        'value': normalized,
        'brightnessPercent': (normalized * 100).round(),
      }),
    );
  }

  Future<void> _showSaveImageDialog(String imageUrl) async {
    unawaited(HapticFeedback.heavyImpact());
    final strings = l10n(context);
    final dialogTheme = _resolveReaderTheme(context);
    _logReaderEvent(
      'Reader save image dialog opened',
      source: 'reader_media',
      content: _readerLogPayload({'imageUrl': imageUrl}),
    );
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
        return Theme(
          data: dialogTheme,
          child: AlertDialog(
            backgroundColor: dialogTheme.colorScheme.surfaceContainerHigh,
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
          ),
        );
      },
    );
    if (shouldSave != true || !mounted) {
      _logReaderEvent(
        'Reader save image cancelled',
        source: 'reader_media',
        content: _readerLogPayload({'imageUrl': imageUrl}),
      );
      return;
    }
    _logReaderEvent(
      'Reader save image confirmed',
      source: 'reader_media',
      content: _readerLogPayload({'imageUrl': imageUrl}),
    );
    try {
      Uint8List bytes;
      String outputExtension = 'png';

      if (_sessionController.isLocalImagePath(imageUrl)) {
        final file = File(_sessionController.normalizeLocalImagePath(imageUrl));
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
        final prepared = await _sessionController.prepareImageForSave(
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
      Directory directory;
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        directory = Directory('$exeDir/Saved_Images');
      } else {
        directory = Directory('/storage/emulated/0/Pictures/Hazuki');
      }
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File('${directory.path}/$saveName');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) {
        return;
      }
      _logReaderEvent(
        'Reader image saved',
        source: 'reader_media',
        content: _readerLogPayload({
          'imageUrl': imageUrl,
          'savedPath': file.path,
        }),
      );
      unawaited(showHazukiPrompt(context, strings.comicDetailSavedToPath));
    } catch (error) {
      _logReaderEvent(
        'Reader image save failed',
        level: 'error',
        source: 'reader_media',
        content: _readerLogPayload({'imageUrl': imageUrl, 'error': '$error'}),
      );
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.comicDetailSaveFailed('$error'),
          isError: true,
        ),
      );
    }
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
