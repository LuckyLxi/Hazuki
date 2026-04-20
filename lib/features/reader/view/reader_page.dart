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
import 'package:hazuki/features/comic_detail/view/comic_detail_panels.dart';
import 'package:hazuki/features/reader/reader.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/view/reader_overlay_controls.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';
import 'package:hazuki/features/reader/view/reader_settings_drawer_content.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';
import 'package:hazuki/features/reader/view/reader_state_views.dart';

part 'reader_settings_actions.dart';
part 'reader_chapter_actions.dart';
part 'reader_media_actions.dart';
part 'reader_image_views.dart';
part 'reader_overlay_builders.dart';
part 'reader_diagnostics_actions.dart';

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

  bool get _noImageModeEnabled => hazukiNoImageModeNotifier.value;

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
  void dispose() {
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
}

class _ReaderScrollPhysics extends ClampingScrollPhysics {
  const _ReaderScrollPhysics({super.parent});

  @override
  _ReaderScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ReaderScrollPhysics(parent: buildParent(ancestor));
  }
}
