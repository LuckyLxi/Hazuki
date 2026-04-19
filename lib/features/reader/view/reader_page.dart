import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_page.dart';
import 'package:hazuki/features/reader/reader.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/view/reader_overlay_controls.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/features/reader/view/reader_settings_drawer_content.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';
import 'package:hazuki/features/reader/view/reader_state_views.dart';

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
        resetZoomImmediately: _resetZoomImmediately,
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
        onZoomChanged: _onZoomChanged,
        comicId: widget.comicId,
        epId: widget.epId,
        chapterTitle: widget.chapterTitle,
        chapterIndex: widget.chapterIndex,
        widgetImages: widget.images,
      );

  ComicDetailsData? _chapterDetailsCache;
  bool _chapterPanelLoading = false;

  bool get _noImageModeEnabled => hazukiNoImageModeNotifier.value;

  String get _readerSessionId => _displayBridge.sessionId;

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
      math.min(value.round(), _runtimeState.readerSpreadCount - 1),
    );
    if (_runtimeState.lastSliderHapticPageIndex == targetIndex) {
      return;
    }
    _runtimeState.lastSliderHapticPageIndex = targetIndex;
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _handlePlatformVolumeButtonPressed(String? direction) {
    return _navigationController.handlePlatformVolumeButtonPressed(direction);
  }

  @override
  void initState() {
    super.initState();
    _sessionController.initialize();
  }

  @override
  void dispose() {
    _resetAnimController.dispose();
    _sessionController.dispose();
    super.dispose();
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
      readerSessionId: _readerSessionId,
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
    HazukiSourceService.instance.addReaderLog(
      level: level,
      title: title,
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

  void _handleBackPressed() {
    _logReaderEvent('Reader back pressed', source: 'reader_navigation');
    Navigator.of(context).maybePop();
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
      _resetZoomImmediately(reason: 'reading_mode_changed');
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
      _resetZoomImmediately(reason: 'double_page_mode_changed');
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
      _resetZoomImmediately(reason: 'pinch_to_zoom_disabled');
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
          await HazukiSourceService.instance.loadComicDetails(widget.comicId);
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
          await HazukiSourceService.instance.loadComicDetails(widget.comicId);
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

  void _onZoomChanged() {
    final scale = _zoomController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (_runtimeState.zoomInteracting) {
      _runtimeState.isZoomed = zoomed;
      return;
    }
    if (zoomed != _runtimeState.isZoomed && mounted) {
      _updateReaderState(() => _runtimeState.isZoomed = zoomed);
    }
  }

  void _handleReaderPointerDown(PointerDownEvent _) {
    final previousCount = _runtimeState.activePointerCount;
    _runtimeState.activePointerCount = previousCount + 1;
    if (!_runtimeState.pinchToZoom ||
        previousCount > 1 ||
        _runtimeState.activePointerCount <= 1 ||
        !mounted) {
      return;
    }
    _updateReaderState(() {
      _runtimeState.zoomInteracting = true;
    });
  }

  void _handleReaderPointerEnd(PointerEvent _) {
    final previousCount = _runtimeState.activePointerCount;
    _runtimeState.activePointerCount = math.max(0, previousCount - 1);
    if (!_runtimeState.pinchToZoom ||
        previousCount <= 1 ||
        _runtimeState.activePointerCount > 1) {
      return;
    }
    final zoomed = _zoomController.value.getMaxScaleOnAxis() > 1.05;
    if (!mounted) {
      _runtimeState.zoomInteracting = false;
      _runtimeState.isZoomed = zoomed;
      if (!zoomed) {
        _zoomController.value = Matrix4.identity();
      }
      return;
    }
    _updateReaderState(() {
      _runtimeState.zoomInteracting = false;
      _runtimeState.isZoomed = zoomed;
    });
    if (!zoomed) {
      _zoomController.value = Matrix4.identity();
    }
  }

  void _handleZoomInteractionStart(ScaleStartDetails _) {
    if (!mounted) {
      _runtimeState.zoomInteracting = true;
      return;
    }
    _updateReaderState(() {
      _runtimeState.zoomInteracting = true;
    });
  }

  void _handleZoomInteractionUpdate(ScaleUpdateDetails _) {
    final zoomed = _zoomController.value.getMaxScaleOnAxis() > 1.05;
    if (!mounted) {
      _runtimeState.isZoomed = zoomed;
      return;
    }
    if (zoomed != _runtimeState.isZoomed) {
      _updateReaderState(() {
        _runtimeState.isZoomed = zoomed;
      });
    }
  }

  void _handleZoomInteractionEnd(ScaleEndDetails _) {
    final zoomed = _zoomController.value.getMaxScaleOnAxis() > 1.05;
    if (!mounted) {
      _runtimeState.zoomInteracting = _runtimeState.activePointerCount > 1;
      _runtimeState.isZoomed = zoomed;
      if (!zoomed) {
        _zoomController.value = Matrix4.identity();
      }
      return;
    }
    _updateReaderState(() {
      _runtimeState.zoomInteracting = _runtimeState.activePointerCount > 1;
      _runtimeState.isZoomed = zoomed;
    });
    if (!zoomed) {
      _zoomController.value = Matrix4.identity();
    }
  }

  void _resetZoom() {
    final controller = _zoomController;
    final startScale = controller.value.getMaxScaleOnAxis();
    _logReaderEvent(
      'Reader zoom reset animated',
      source: 'reader_zoom',
      content: _readerLogPayload({
        'trigger': 'manual_reset_button',
        'previousScale': _normalizeLogDouble(startScale),
      }),
    );

    final Matrix4 start = controller.value.clone();
    final Matrix4 end = Matrix4.identity();
    _resetAnimController.reset();
    final Animation<double> anim = CurvedAnimation(
      parent: _resetAnimController,
      curve: Curves.easeOutCubic,
    );
    void listener() {
      final t = anim.value;
      final Matrix4 current = Matrix4.zero();
      for (var i = 0; i < 16; i++) {
        current[i] = start[i] + (end[i] - start[i]) * t;
      }
      controller.value = current;
    }

    anim.addListener(listener);
    _resetAnimController.forward().whenComplete(() {
      anim.removeListener(listener);
      controller.value = Matrix4.identity();
      if (!mounted) {
        _runtimeState.isZoomed = false;
        _runtimeState.zoomInteracting = false;
        return;
      }
      _updateReaderState(() {
        _runtimeState.isZoomed = false;
        _runtimeState.zoomInteracting = false;
      });
    });
  }

  void _resetZoomImmediately({String reason = 'unspecified'}) {
    final previousScale = _zoomController.value.getMaxScaleOnAxis();
    final hadZoomState =
        _runtimeState.isZoomed ||
        _runtimeState.zoomInteracting ||
        _runtimeState.activePointerCount > 0 ||
        previousScale > 1.001;
    _resetAnimController.stop();
    _zoomController.value = Matrix4.identity();
    _runtimeState.zoomInteracting = false;
    _runtimeState.activePointerCount = 0;
    _runtimeState.isZoomed = false;
    if (hadZoomState) {
      _logReaderEvent(
        'Reader zoom reset immediately',
        source: 'reader_zoom',
        content: _readerLogPayload({
          'trigger': reason,
          'previousScale': _normalizeLogDouble(previousScale),
        }),
      );
    }
  }

  Widget _buildZoomableReader({
    required Widget child,
    bool constrained = true,
  }) {
    return InteractiveViewer(
      transformationController: _zoomController,
      panEnabled: _runtimeState.isZoomed || _runtimeState.zoomInteracting,
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
    if (!_runtimeState.pinchToZoom ||
        _runtimeState.readerMode != ReaderMode.rightToLeft ||
        index != _runtimeState.currentPageIndex) {
      return child;
    }
    return _buildZoomableReader(child: child);
  }

  Widget _buildReaderListView() {
    return NotificationListener<ScrollNotification>(
      onNotification: _navigationController.handleScrollNotification,
      child: ListView.builder(
        key: PageStorageKey<String>(
          'reader-list-${widget.comicId}-${widget.epId}-${_runtimeState.readerSpreadSize}',
        ),
        padding: EdgeInsets.zero,
        cacheExtent: _imagePipelineController.readerListCacheExtent(context),
        itemCount: _runtimeState.readerSpreadCount,
        controller: _scrollController,
        physics: _runtimeState.zoomGestureActive
            ? const NeverScrollableScrollPhysics()
            : const _ReaderScrollPhysics(),
        itemBuilder: (context, index) => _buildReaderListItem(index),
      ),
    );
  }

  Widget _buildReaderPageImage(int imageIndex) {
    final url = _runtimeState.images[imageIndex];
    final cachedProvider = _imagePipelineController.cachedProviderFor(url);
    final readerSurfaceColor = _resolveReaderSurfaceColor(context);
    final readerPlaceholderColor = _resolveReaderPlaceholderColor(context);

    if (_noImageModeEnabled) {
      return const SizedBox.expand();
    }

    Widget buildImage(ImageProvider provider) {
      return _wrapImageWidget(
        ColoredBox(
          color: readerSurfaceColor,
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
                return ColoredBox(color: readerSurfaceColor);
              },
              errorBuilder: (_, _, _) {
                return _buildReaderImageErrorView(
                  url,
                  backgroundColor: readerPlaceholderColor,
                );
              },
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
      future: _imagePipelineController.getImageProvider(url),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return buildImage(snapshot.data!);
        }
        if (snapshot.hasError) {
          return _buildReaderImageErrorView(
            url,
            backgroundColor: readerPlaceholderColor,
          );
        }
        return ColoredBox(
          color: readerSurfaceColor,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }

  Widget _buildReaderPageSpread(int spreadIndex) {
    final imageIndices = _runtimeState.spreadImageIndices(spreadIndex);
    if (imageIndices.isEmpty) {
      return const SizedBox.expand();
    }

    final spreadContent = imageIndices.length == 1
        ? _buildReaderPageImage(imageIndices.first)
        : Row(
            children: [
              Expanded(child: _buildReaderPageImage(imageIndices[0])),
              Expanded(child: _buildReaderPageImage(imageIndices[1])),
            ],
          );

    return _wrapPageWithPinchZoom(index: spreadIndex, child: spreadContent);
  }

  Widget _buildReaderPageView() {
    return PageView.builder(
      key: PageStorageKey<String>(
        'reader-page-${widget.comicId}-${widget.epId}-rtl-${_runtimeState.readerSpreadSize}',
      ),
      controller: _pageController,
      reverse: false,
      allowImplicitScrolling: true,
      itemCount: _runtimeState.readerSpreadCount,
      physics: _runtimeState.pageNavigationLocked
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: _navigationController.handlePageChanged,
      itemBuilder: (context, index) {
        return _buildReaderPageSpread(index);
      },
    );
  }

  Widget _buildTopToBottomReaderView() {
    if (!_runtimeState.pinchToZoom ||
        _runtimeState.readerMode != ReaderMode.topToBottom) {
      return _buildReaderListView();
    }
    return _buildZoomableReader(child: _buildReaderListView());
  }

  Widget _wrapReaderTapPaging(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            unawaited(
              _navigationController.handleTapUp(details, constraints.maxWidth),
            );
          },
          child: child,
        );
      },
    );
  }

  Widget _buildReaderListItem(int spreadIndex) {
    final imageIndices = _runtimeState.spreadImageIndices(spreadIndex);
    if (imageIndices.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      key: spreadIndex < _runtimeState.itemKeys.length
          ? _runtimeState.itemKeys[spreadIndex]
          : null,
      child: imageIndices.length == 1
          ? _buildReaderListImage(imageIndices.first)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildReaderListImage(imageIndices[0])),
                Expanded(child: _buildReaderListImage(imageIndices[1])),
              ],
            ),
    );
  }

  Widget _buildReaderListImage(int imageIndex) {
    final url = _runtimeState.images[imageIndex];
    final cachedProvider = _imagePipelineController.cachedProviderFor(url);
    final readerSurfaceColor = _resolveReaderSurfaceColor(context);
    final readerPlaceholderColor = _resolveReaderPlaceholderColor(context);

    double? currentResolvedAspectRatio() {
      return _imagePipelineState.imageAspectRatioCache[url];
    }

    double currentPlaceholderAspectRatio() {
      return currentResolvedAspectRatio() ??
          _imagePipelineController.resolvePlaceholderAspectRatio(imageIndex);
    }

    if (_noImageModeEnabled) {
      return AspectRatio(
        aspectRatio: currentPlaceholderAspectRatio(),
        child: const SizedBox.expand(),
      );
    }

    Widget buildImageError({required bool stableAspectRatio}) {
      final errorView = _buildReaderImageErrorView(
        url,
        compact: true,
        backgroundColor: readerPlaceholderColor,
      );
      if (!stableAspectRatio) {
        return errorView;
      }
      return ColoredBox(
        color: readerSurfaceColor,
        child: AspectRatio(
          aspectRatio: currentPlaceholderAspectRatio(),
          child: errorView,
        ),
      );
    }

    Widget buildImage(ImageProvider provider) {
      final resolvedAspectRatio = currentResolvedAspectRatio();
      final image = Image(
        key: ValueKey(url),
        image: provider,
        fit: resolvedAspectRatio != null ? BoxFit.fill : BoxFit.fitWidth,
        width: double.infinity,
        height: resolvedAspectRatio != null ? double.infinity : null,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return ColoredBox(color: readerSurfaceColor);
        },
        errorBuilder: (_, _, _) {
          return buildImageError(stableAspectRatio: false);
        },
      );
      final stableImage = resolvedAspectRatio == null
          ? image
          : ColoredBox(
              color: readerSurfaceColor,
              child: AspectRatio(
                aspectRatio: resolvedAspectRatio,
                child: image,
              ),
            );
      return _wrapImageWidget(stableImage, url);
    }

    if (cachedProvider != null) {
      return buildImage(cachedProvider);
    }

    return FutureBuilder<ImageProvider>(
      key: ValueKey(url),
      future: _imagePipelineController.getImageProvider(url),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return buildImage(snapshot.data!);
        }
        if (snapshot.hasError) {
          return AspectRatio(
            aspectRatio: currentPlaceholderAspectRatio(),
            child: buildImageError(stableAspectRatio: false),
          );
        }
        return AspectRatio(
          aspectRatio: currentPlaceholderAspectRatio(),
          child: DecoratedBox(
            decoration: BoxDecoration(color: readerSurfaceColor),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReaderImageErrorView(
    String url, {
    bool compact = false,
    Color? backgroundColor,
  }) {
    final isRetrying = _imagePipelineController.isRetrying(url);
    final theme = Theme.of(context);
    final surfaceColor = backgroundColor ?? _resolveReaderPlaceholderColor();
    final foregroundColor = theme.colorScheme.onSurfaceVariant;

    return ColoredBox(
      color: surfaceColor,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 20,
            vertical: compact ? 16 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 220 : 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: foregroundColor,
                  size: compact ? 28 : 36,
                ),
                SizedBox(height: compact ? 10 : 14),
                FilledButton.tonalIcon(
                  onPressed: isRetrying
                      ? null
                      : () =>
                            unawaited(_imagePipelineController.retryImage(url)),
                  icon: isRetrying
                      ? SizedBox(
                          width: compact ? 14 : 16,
                          height: compact ? 14 : 16,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(l10n(context).commonRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderSettingsDrawer(ThemeData readerTheme) {
    final drawerWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.88,
      360.0,
    );

    return Theme(
      data: readerTheme,
      child: Builder(
        builder: (drawerContext) {
          return Drawer(
            width: drawerWidth,
            child: ReaderSettingsDrawerContent(
              readerMode: _runtimeState.readerMode,
              doublePageMode: _runtimeState.doublePageMode,
              tapToTurnPage: _runtimeState.tapToTurnPage,
              volumeButtonTurnPage: _runtimeState.volumeButtonTurnPage,
              pinchToZoom: _runtimeState.pinchToZoom,
              longPressToSave: _runtimeState.longPressToSave,
              immersiveMode: _runtimeState.immersiveMode,
              keepScreenOn: _runtimeState.keepScreenOn,
              pageIndicator: _runtimeState.pageIndicator,
              customBrightness: _runtimeState.customBrightness,
              brightnessValue: _runtimeState.brightnessValue,
              onReaderModeChanged: _updateReaderModeSetting,
              onDoublePageModeChanged: _toggleDoublePageModeSetting,
              onTapToTurnPageChanged:
                  _runtimeState.readerMode == ReaderMode.rightToLeft
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
              onClose: () => Navigator.of(drawerContext).pop(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReaderTopControls(ThemeData readerTheme) {
    return ReaderTopControls(
      controlsVisible: _runtimeState.controlsVisible,
      readerTheme: readerTheme,
      title: widget.title,
      settingsTooltip: l10n(context).readingSettingsTitle,
      onBackPressed: _handleBackPressed,
      onOpenSettingsDrawer: _openReaderSettingsDrawer,
    );
  }

  Widget _buildReaderPageIndicator(ThemeData readerTheme) {
    return ReaderPageIndicatorOverlay(
      controlsVisible: _runtimeState.controlsVisible,
      readerTheme: readerTheme,
      pageIndexNotifier: _runtimeState.pageIndexNotifier,
      chapterIndex: widget.chapterIndex,
      imageCount: _runtimeState.readerSpreadCount,
    );
  }

  Widget _buildReaderBottomControls(ThemeData readerTheme) {
    final maxIndex = math.max(_runtimeState.readerSpreadCount - 1, 0);
    return ReaderBottomControls(
      controlsVisible: _runtimeState.controlsVisible,
      readerTheme: readerTheme,
      pageIndexNotifier: _runtimeState.pageIndexNotifier,
      sliderDragging: _runtimeState.sliderDragging,
      sliderDragValue: _runtimeState.sliderDragValue,
      imageCount: _runtimeState.readerSpreadCount,
      chapterPanelLoading: _chapterPanelLoading,
      onSliderChangeStart: _runtimeState.readerSpreadCount > 1
          ? (value) {
              _runtimeState.lastSliderHapticPageIndex = null;
              _maybeTriggerSliderHaptic(value);
              _updateReaderState(() {
                _runtimeState.sliderDragging = true;
                _runtimeState.sliderDragValue = value;
              });
            }
          : null,
      onSliderChanged: _runtimeState.readerSpreadCount > 1
          ? (value) {
              _maybeTriggerSliderHaptic(value);
              _updateReaderState(() {
                _runtimeState.sliderDragging = true;
                _runtimeState.sliderDragValue = value;
              });
            }
          : null,
      onSliderChangeEnd: _runtimeState.readerSpreadCount > 1
          ? (value) {
              final target = math.max(0, math.min(value.round(), maxIndex));
              _runtimeState.lastSliderHapticPageIndex = null;
              _updateReaderState(() {
                _runtimeState.sliderDragging = false;
                _runtimeState.sliderDragValue = target.toDouble();
              });
              unawaited(
                _navigationController.goToPage(
                  target,
                  trigger: 'bottom_slider',
                ),
              );
            }
          : null,
      onOpenChaptersPanel: _openChaptersPanel,
    );
  }

  Widget _buildReaderChapterJumpOverlay() {
    return ReaderChapterJumpOverlay(
      controlsVisible: _runtimeState.controlsVisible,
      onPreviousChapter: () {
        unawaited(_jumpToAdjacentChapter(-1));
      },
      onNextChapter: () {
        unawaited(_jumpToAdjacentChapter(1));
      },
      previousTooltip: l10n(context).readerPreviousChapter,
      nextTooltip: l10n(context).readerNextChapter,
    );
  }

  Widget _buildReaderZoomResetOverlay() {
    return ReaderZoomResetOverlay(
      controlsVisible: _runtimeState.controlsVisible,
      isZoomed: _runtimeState.isZoomed,
      onResetZoom: _resetZoom,
      label: l10n(context).readerResetZoom,
    );
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
                  onPointerDown: _handleReaderPointerDown,
                  onPointerUp: _handleReaderPointerEnd,
                  onPointerCancel: _handleReaderPointerEnd,
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
}

class _ReaderScrollPhysics extends ClampingScrollPhysics {
  const _ReaderScrollPhysics({super.parent});

  @override
  _ReaderScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ReaderScrollPhysics(parent: buildParent(ancestor));
  }
}
