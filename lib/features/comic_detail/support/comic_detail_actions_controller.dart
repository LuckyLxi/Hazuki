import 'package:hazuki/services/source/source_task_owner.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:hazuki/shared/reading/reader_entry_position.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/shared/chapter_title_resolver.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/window_title_bar_control.dart';
import 'package:hazuki/shared/category_tag_navigation.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/manga_download/manga_download_commands.dart';
import 'package:hazuki/services/media/image_actions_service.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';
import 'package:hazuki/widgets/expanding_chapter_sheet.dart';
import 'package:hazuki/shared/downloads/chapter_download_flow.dart';

import '../repository/comic_detail_repository.dart';
import 'comic_detail_controller_support.dart';
import 'comic_detail_download_conflict_dialog.dart';

class ComicDetailActionsController extends ChangeNotifier {
  ComicDetailActionsController({
    required SourceTaskControlGateway taskControl,
    required ComicDetailFeatureFacade repository,
    required MangaDownloadCommands downloader,
    required ExploreComic comic,
    required String heroTag,
    required ThemeData Function(ThemeData) detailThemeApplier,
    required Map<String, dynamic>? Function() lastReadProgressGetter,
    required Future<void> Function() reloadReadingProgress,
    required ComicDetailCoverPreviewPageBuilder coverPreviewPageBuilder,
    required ComicChaptersPanelBuilder chaptersPanelBuilder,
    required ComicDetailReaderPageBuilder readerPageBuilder,
    required ComicDetailSearchPageBuilder searchPageBuilder,
    required ComicDetailNestedPageBuilder comicDetailPageBuilder,
    ComicDetailCategoryPageBuilder? categoryPageBuilder,
    ImageActionsService imageActions = const ImageActionsService(),
    required Route<void> Function(WidgetBuilder) destinationRouteBuilder,
    required Route<void> Function(WidgetBuilder) expandedReaderRouteBuilder,
  }) : _readTasks = SourceTaskOwner(taskControl),
       _progressTasks = SourceTaskOwner(taskControl),
       _destinationRouteBuilder = destinationRouteBuilder,
       _expandedReaderRouteBuilder = expandedReaderRouteBuilder,
       _repository = repository,
       _downloader = downloader,
       _comic = comic,
       _heroTag = heroTag,
       _detailThemeApplier = detailThemeApplier,
       _lastReadProgressGetter = lastReadProgressGetter,
       _reloadReadingProgress = reloadReadingProgress,
       _coverPreviewPageBuilder = coverPreviewPageBuilder,
       _chaptersPanelBuilder = chaptersPanelBuilder,
       _readerPageBuilder = readerPageBuilder,
       _searchPageBuilder = searchPageBuilder,
       _comicDetailPageBuilder = comicDetailPageBuilder,
       _categoryPageBuilder = categoryPageBuilder,
       _imageActions = imageActions;

  final Route<void> Function(WidgetBuilder) _destinationRouteBuilder;
  final Route<void> Function(WidgetBuilder) _expandedReaderRouteBuilder;
  final ComicDetailFeatureFacade _repository;
  final MangaDownloadCommands _downloader;
  final ExploreComic _comic;
  final String _heroTag;
  final ThemeData Function(ThemeData) _detailThemeApplier;
  final Map<String, dynamic>? Function() _lastReadProgressGetter;
  final Future<void> Function() _reloadReadingProgress;
  final ComicDetailCoverPreviewPageBuilder _coverPreviewPageBuilder;
  final ComicChaptersPanelBuilder _chaptersPanelBuilder;
  final ComicDetailReaderPageBuilder _readerPageBuilder;
  final ComicDetailSearchPageBuilder _searchPageBuilder;
  final ComicDetailNestedPageBuilder _comicDetailPageBuilder;
  final ComicDetailCategoryPageBuilder? _categoryPageBuilder;
  final ImageActionsService _imageActions;

  final SourceTaskOwner _readTasks;
  final SourceTaskOwner _progressTasks;
  bool _disposed = false;
  int _readerOpenRequest = 0;

  /// [heroTag] 为空时使用封面的 hero，插件标签页图片传入各自的 hero。
  Future<void> showCoverPreview(
    BuildContext context,
    String imageUrl, {
    String? heroTag,
  }) async {
    final normalized = imageUrl.trim();
    if (normalized.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    await precacheComicCoverHeroImages(
      context,
      url: normalized,
      sourceKey: _comic.sourceKey,
      sourceCacheWidth: (135 * devicePixelRatio)
          .round()
          .clamp(135, 640)
          .toInt(),
      sourceCacheHeight: (190 * devicePixelRatio)
          .round()
          .clamp(190, 900)
          .toInt(),
    );
    if (!context.mounted) {
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black45,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _coverPreviewPageBuilder(
            imageUrl: normalized,
            sourceKey: _comic.sourceKey,
            heroTag: heroTag ?? _heroTag,
            onLongPress: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(_showCoverActions(context, normalized));
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  void showChaptersPanel(BuildContext context, ComicDetailsData details) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (details.chapters.isEmpty) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailNoChapterInfo,
          isError: true,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      sheetAnimationStyle: AnimationStyle(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutQuart,
        reverseDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (routeContext) {
        return _wrapWithDetailTheme(
          routeContext,
          ExpandingChapterSheet(
            cornerRadius: 28,
            safePadding: MediaQuery.paddingOf(context),
            builder: (sheetContext) => _chaptersPanelBuilder(
              details: details,
              readingProgress: _lastReadProgressGetter(),
              onResume: (cardContext) {
                unawaited(
                  _resumeFromChapterSheet(
                    context,
                    sheetContext,
                    cardContext,
                    details,
                  ),
                );
              },
              onDownloadConfirm: (selectedEpIds) {
                Navigator.of(sheetContext).pop();
                unawaited(
                  _enqueueChapterDownloads(
                    context,
                    details,
                    selectedEpIds: selectedEpIds,
                  ),
                );
              },
              onChapterTap: (epId, chapterTitle, index) {
                unawaited(
                  _openReaderFromChapterSheet(
                    context,
                    sheetContext,
                    details,
                    epId: epId,
                    chapterTitle: chapterTitle,
                    chapterIndex: index,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openReaderFromChapterSheet(
    BuildContext context,
    BuildContext sheetContext,
    ComicDetailsData details, {
    required String epId,
    required String chapterTitle,
    required int chapterIndex,
  }) async {
    final navigator = Navigator.of(sheetContext);
    final sheetRoute = ModalRoute.of(sheetContext)!;
    if (!await ExpandingChapterSheet.expand(sheetContext) ||
        _disposed ||
        !context.mounted) {
      return;
    }
    final readerClosed = openReader(
      context,
      details,
      epId: epId,
      chapterTitle: chapterTitle,
      chapterIndex: chapterIndex,
      fromExpandedChapterSheet: true,
    );
    navigator.removeRoute(sheetRoute);
    await readerClosed;
  }

  /// 继续阅读卡片：卡片以圆角放大到全屏后，按上次进度（含页码）打开阅读器。
  Future<void> _resumeFromChapterSheet(
    BuildContext context,
    BuildContext sheetContext,
    BuildContext cardContext,
    ComicDetailsData details,
  ) async {
    final progress = _lastReadProgressGetter();
    final epId = progress?['epId'];
    if (epId is! String || !details.chapters.containsKey(epId)) return;
    final navigator = Navigator.of(sheetContext);
    final sheetRoute = ModalRoute.of(sheetContext)!;
    if (!await ExpandingChapterSheet.expandFrom(
          sheetContext,
          source: cardContext,
          color: Theme.of(cardContext).colorScheme.primaryContainer,
          radius: 20,
        ) ||
        _disposed ||
        !context.mounted) {
      return;
    }
    final readerClosed = openReader(
      context,
      details,
      epId: epId,
      chapterTitle: resolveHazukiChapterTitle(context, details.chapters[epId]!),
      chapterIndex: details.chapters.keys.toList().indexOf(epId),
      fromExpandedChapterSheet: true,
      entryProgress: progress,
    );
    navigator.removeRoute(sheetRoute);
    await readerClosed;
  }

  Future<void> openReader(
    BuildContext context,
    ComicDetailsData details, {
    String? epId,
    String? chapterTitle,
    int? chapterIndex,
    bool fromExpandedChapterSheet = false,
    Map<String, dynamic>? entryProgress,
  }) async {
    if (_disposed) return;
    final readerRequest = ++_readerOpenRequest;
    _progressTasks.restart();
    final origin = _progressTasks.origin();
    FocusManager.instance.primaryFocus?.unfocus();
    final chapters = details.chapters;
    if (chapters.isEmpty) {
      if (_disposed) return;
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailNoChapters,
          isError: true,
        ),
      );
      return;
    }

    MapEntry<String, String>? initialEntry;
    int finalIndex = 0;

    var lastReadProgress = _lastReadProgressGetter();
    if (epId == null) {
      try {
        if (await _repository.usesWebsiteReadingProgress(taskOrigin: origin)) {
          lastReadProgress = await _repository.loadReadingProgress(
            _comic.id,
            taskOrigin: origin,
          );
        }
      } catch (error) {
        if (error is SourceTaskCancelled ||
            _disposed ||
            readerRequest != _readerOpenRequest) {
          return;
        }
        lastReadProgress = null;
        if (_disposed || !context.mounted) return;
        unawaited(
          showHazukiPrompt(
            context,
            l10n(context).sourceCloudProgressUnavailable,
            isError: true,
          ),
        );
      }
      if (_disposed ||
          !context.mounted ||
          readerRequest != _readerOpenRequest ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (lastReadProgress?['cloud'] == true &&
          !chapters.containsKey(lastReadProgress?['epId'])) {
        unawaited(
          showHazukiPrompt(
            context,
            l10n(context).sourceCloudChapterMissing,
            isError: true,
          ),
        );
        return;
      }
    }
    final hasMemory =
        lastReadProgress != null &&
        chapters.containsKey(lastReadProgress['epId']);

    if (epId != null && chapters.containsKey(epId)) {
      initialEntry = MapEntry(epId, chapters[epId]!);
      finalIndex = chapterIndex ?? chapters.keys.toList().indexOf(epId);
    } else if (hasMemory) {
      final memEpId = lastReadProgress['epId'] as String;
      initialEntry = MapEntry(memEpId, chapters[memEpId]!);
      finalIndex = chapters.keys.toList().indexOf(memEpId);
    } else {
      initialEntry = chapters.entries.first;
      finalIndex = 0;
    }

    final initialChapterTitle = resolveHazukiChapterTitle(
      context,
      (chapterTitle != null && chapterTitle.isNotEmpty)
          ? chapterTitle
          : initialEntry.value,
    );

    final titleBarController = Platform.isWindows
        ? HazukiWindowsTitleBarScope.of(context)
        : null;
    final titleBarSuppressionOwner = Object();
    titleBarController?.suppressCustomTitleBar(titleBarSuppressionOwner);
    try {
      await Navigator.of(context, rootNavigator: true).push(
        (fromExpandedChapterSheet
            ? _expandedReaderRouteBuilder
            : _destinationRouteBuilder)(
          (_) => ReaderEntryPosition(
            progress: epId == null ? lastReadProgress : entryProgress,
            child: _readerPageBuilder(
              details: details,
              chapterTitle: initialChapterTitle,
              epId: initialEntry!.key,
              chapterIndex: finalIndex,
              comicTheme: _detailThemeApplier(Theme.of(context)),
            ),
          ),
        ),
      );
    } finally {
      titleBarController?.releaseCustomTitleBarSuppression(
        titleBarSuppressionOwner,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      if (!_disposed) unawaited(_reloadReadingProgress());
    }
  }

  Future<void> copyComicId(BuildContext context, String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: trimmedId));
    if (_disposed) return;
    unawaited(showHazukiPrompt(context, l10n(context).comicDetailCopiedId));
  }

  Future<void> openSearchForKeyword(BuildContext context, String value) async {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return;

    await _pushTagDestination(context, (_) => _searchPageBuilder(trimmedValue));
  }

  Future<void> openTagValue(BuildContext context, String value) async {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return;

    _readTasks.restart();
    final generation = _readTasks.generation;
    try {
      final groups = await _repository.loadCategoryTagGroups(
        taskOrigin: _readTasks.origin(),
      );
      if (generation != _readTasks.generation) return;
      if (_disposed) {
        return;
      }
      final target = resolveCategoryTagNavigationTarget(groups, trimmedValue);
      final categoryPageBuilder = _categoryPageBuilder;
      if (target != null && categoryPageBuilder != null) {
        await _pushTagDestination(
          context,
          (_) => categoryPageBuilder(
            title: target.title,
            viewMoreUrl: target.viewMoreUrl,
            comicDetailPageBuilder: _comicDetailPageBuilder,
          ),
        );
        return;
      }
    } catch (error) {
      if (_disposed ||
          generation != _readTasks.generation ||
          isSourceTaskCancellation(error)) {
        return;
      }
      // Fall back to the legacy search behavior when category metadata is not
      // available for the current source.
    }

    if (_disposed) {
      return;
    }
    await openSearchForKeyword(context, trimmedValue);
  }

  Future<void> _pushTagDestination(
    BuildContext context,
    WidgetBuilder builder,
  ) async {
    await Navigator.of(context).push(_destinationRouteBuilder(builder));
  }

  Future<void> copyMetaValue(BuildContext context, String value) async {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return;
    unawaited(HapticFeedback.heavyImpact());
    await Clipboard.setData(ClipboardData(text: trimmedValue));
    if (_disposed) return;
    unawaited(
      showHazukiPrompt(
        context,
        l10n(context).comicDetailCopiedPrefix(trimmedValue),
      ),
    );
  }

  Future<void> _saveImageToDownloads(
    BuildContext context,
    String imageUrl,
  ) async {
    try {
      final bytes = await _repository.downloadImageBytes(
        imageUrl,
        sourceKey: _comic.sourceKey,
      );
      final uri = Uri.tryParse(imageUrl);
      final lastSegment = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : '';
      final defaultName = 'hazuki_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileName = lastSegment.isEmpty
          ? defaultName
          : lastSegment.split('?').first;
      final extension =
          RegExp(
            r'\.([a-zA-Z0-9]{1,10})$',
          ).firstMatch(fileName)?.group(1)?.toLowerCase() ??
          'jpg';
      await _imageActions.saveImage(bytes, extension, fileName);
      if (_disposed) return;
      unawaited(
        showHazukiPrompt(context, l10n(context).comicDetailSavedToPath),
      );
    } catch (e) {
      if (_disposed) return;
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _showCoverActions(BuildContext context, String imageUrl) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _wrapWithDetailTheme(
          context,
          AlertDialog(
            title: Text(l10n(context).comicDetailSaveImage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n(context).commonCancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_saveImageToDownloads(context, imageUrl));
                },
                child: Text(l10n(context).commonSave),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final fadeCurved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scaleCurved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: fadeCurved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(scaleCurved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _enqueueChapterDownloads(
    BuildContext context,
    ComicDetailsData details, {
    required Set<String> selectedEpIds,
  }) async {
    if (selectedEpIds.isEmpty) return;
    final targets = <MangaChapterDownloadTarget>[];
    for (var i = 0; i < details.chapters.length; i++) {
      final entry = details.chapters.entries.elementAt(i);
      if (selectedEpIds.contains(entry.key)) {
        targets.add(
          MangaChapterDownloadTarget(
            epId: entry.key,
            title: resolveHazukiChapterTitle(context, entry.value),
            index: i,
          ),
        );
      }
    }
    if (targets.isEmpty) return;
    bool isActive() => !_disposed && context.mounted;
    late final int queuedCount;
    try {
      final outcome = await enqueueChapterDownloads(
        downloader: _downloader,
        details: details,
        targets: targets,
        coverUrl: details.cover.trim().isNotEmpty
            ? details.cover
            : _comic.cover,
        isActive: isActive,
        chooseDownloadedAction: (conflict) async {
          final action = await showComicDetailSkipDownloadedChaptersDialog(
            context,
            conflict: conflict,
            dialogTheme: _detailThemeApplier(Theme.of(context)),
          );
          if (action == DownloadedChapterConflictAction.continueToRedownload &&
              isActive()) {
            await Future<void>.delayed(const Duration(milliseconds: 260));
          }
          return action;
        },
        confirmRedownload: (conflict) => showComicDetailDownloadConflictDialog(
          context,
          conflict: conflict,
          dialogTheme: _detailThemeApplier(Theme.of(context)),
        ),
      );
      if (outcome == null || !isActive()) return;
      final result = outcome.result;
      if (result == MangaDownloadEnqueueResult.alreadyQueued) {
        unawaited(
          showHazukiPrompt(context, l10n(context).downloadsAlreadyInQueue),
        );
        return;
      }
      if (result == MangaDownloadEnqueueResult.nothingToQueue) {
        return;
      }
      queuedCount = outcome.chapterCount;
    } catch (error) {
      if (_disposed || !context.mounted) return;
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).downloadsQueueFailed('$error'),
          isError: true,
        ),
      );
      return;
    }
    if (_disposed || !context.mounted) return;
    unawaited(
      showHazukiPrompt(context, l10n(context).downloadsQueued('$queuedCount')),
    );
  }

  Widget _wrapWithDetailTheme(BuildContext context, Widget child) {
    return Theme(data: _detailThemeApplier(Theme.of(context)), child: child);
  }

  @override
  void dispose() {
    _disposed = true;
    _progressTasks.dispose();
    _readTasks.dispose();
    super.dispose();
  }
}
