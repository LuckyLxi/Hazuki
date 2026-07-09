// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/shared/chapter_title_resolver.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/app/windows/windows_title_bar_controller.dart';
import 'package:hazuki/shared/category_tag_navigation.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

import '../repository/comic_detail_repository.dart';
import 'comic_detail_controller_support.dart';
import 'comic_detail_download_conflict_dialog.dart';

class ComicDetailActionsController extends ChangeNotifier {
  ComicDetailActionsController({
    required ComicDetailFeatureFacade repository,
    required ExploreComic comic,
    required String heroTag,
    required ThemeData Function(ThemeData) detailThemeApplier,
    required Map<String, dynamic>? Function() lastReadProgressGetter,
    required Future<void> Function() reloadReadingProgress,
    required ComicDetailCoverPreviewPageBuilder coverPreviewPageBuilder,
    required ComicDetailChaptersPanelBuilder chaptersPanelBuilder,
    required ComicDetailReaderPageBuilder readerPageBuilder,
    required ComicDetailSearchPageBuilder searchPageBuilder,
    required ComicDetailNestedPageBuilder comicDetailPageBuilder,
    ComicDetailCategoryPageBuilder? categoryPageBuilder,
    required MethodChannel mediaChannel,
  }) : _repository = repository,
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
       _mediaChannel = mediaChannel;

  final ComicDetailFeatureFacade _repository;
  final ExploreComic _comic;
  final String _heroTag;
  final ThemeData Function(ThemeData) _detailThemeApplier;
  final Map<String, dynamic>? Function() _lastReadProgressGetter;
  final Future<void> Function() _reloadReadingProgress;
  final ComicDetailCoverPreviewPageBuilder _coverPreviewPageBuilder;
  final ComicDetailChaptersPanelBuilder _chaptersPanelBuilder;
  final ComicDetailReaderPageBuilder _readerPageBuilder;
  final ComicDetailSearchPageBuilder _searchPageBuilder;
  final ComicDetailNestedPageBuilder _comicDetailPageBuilder;
  final ComicDetailCategoryPageBuilder? _categoryPageBuilder;
  final MethodChannel _mediaChannel;

  bool _disposed = false;

  Future<void> showCoverPreview(BuildContext context, String imageUrl) async {
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
            heroTag: _heroTag,
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
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        reverseDuration: const Duration(milliseconds: 220),
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (routeContext) {
        return _wrapWithDetailTheme(
          routeContext,
          _chaptersPanelBuilder(
            details: details,
            onDownloadConfirm: (selectedEpIds) {
              Navigator.of(routeContext).pop();
              unawaited(
                _enqueueChapterDownloads(
                  context,
                  details,
                  selectedEpIds: selectedEpIds,
                ),
              );
            },
            onChapterTap: (epId, chapterTitle, index) {
              Navigator.of(routeContext).pop();
              unawaited(
                openReader(
                  context,
                  details,
                  epId: epId,
                  chapterTitle: chapterTitle,
                  chapterIndex: index,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> openReader(
    BuildContext context,
    ComicDetailsData details, {
    String? epId,
    String? chapterTitle,
    int? chapterIndex,
  }) async {
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

    final lastReadProgress = _lastReadProgressGetter();
    final hasMemory =
        lastReadProgress != null &&
        chapters.containsKey(lastReadProgress['epId']) &&
        chapters.length > 1;

    if (epId != null && chapters.containsKey(epId)) {
      initialEntry = MapEntry(epId, chapters[epId]!);
      finalIndex = chapterIndex ?? chapters.keys.toList().indexOf(epId);
    } else if (hasMemory) {
      final memEpId = lastReadProgress['epId'] as String;
      initialEntry = MapEntry(memEpId, chapters[memEpId]!);
      finalIndex = lastReadProgress['index'] as int;
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
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _readerPageBuilder(
            details: details,
            chapterTitle: initialChapterTitle,
            epId: initialEntry!.key,
            chapterIndex: finalIndex,
            comicTheme: _detailThemeApplier(Theme.of(context)),
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

  void openSearchForKeyword(BuildContext context, String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _searchPageBuilder(trimmedValue)),
    );
  }

  Future<void> openTagValue(BuildContext context, String value) async {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return;

    try {
      final groups = await _repository.loadCategoryTagGroups();
      if (_disposed) {
        return;
      }
      final target = resolveCategoryTagNavigationTarget(groups, trimmedValue);
      final categoryPageBuilder = _categoryPageBuilder;
      if (target != null && categoryPageBuilder != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => categoryPageBuilder(
              title: target.title,
              viewMoreUrl: target.viewMoreUrl,
              comicDetailPageBuilder: _comicDetailPageBuilder,
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // Fall back to the legacy search behavior when category metadata is not
      // available for the current source.
    }

    if (_disposed) {
      return;
    }
    openSearchForKeyword(context, trimmedValue);
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
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      if (Platform.isAndroid) {
        await _mediaChannel.invokeMethod<bool>('scanFile', {'path': file.path});
      }
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
    var queuedTargets = targets;
    try {
      final taskConflict = await _repository.checkDownloadTaskConflict(
        details: details,
        chapters: targets,
      );
      if (_disposed || !context.mounted) return;
      if (taskConflict.hasConflict) {
        final queuedEpIds = taskConflict.existingChapters
            .map((chapter) => chapter.epId)
            .toSet();
        queuedTargets = targets
            .where((chapter) => !queuedEpIds.contains(chapter.epId))
            .toList(growable: false);
      }
      if (queuedTargets.isEmpty) {
        if (_disposed || !context.mounted) return;
        unawaited(
          showHazukiPrompt(context, l10n(context).downloadsAlreadyInQueue),
        );
        return;
      }
      final downloadConflictTargets = queuedTargets;
      final conflict = await _repository.checkDownloadConflict(
        details: details,
        chapters: downloadConflictTargets,
      );
      if (_disposed || !context.mounted) return;
      var redownloadExisting = false;
      if (conflict.hasConflict) {
        final hasUndownloadedChapters =
            conflict.existingChapters.length < queuedTargets.length;
        if (hasUndownloadedChapters) {
          final action = await showComicDetailSkipDownloadedChaptersDialog(
            context,
            conflict: conflict,
            dialogTheme: _detailThemeApplier(Theme.of(context)),
          );
          if (action == null || _disposed || !context.mounted) {
            return;
          }
          if (action == ComicDetailDownloadedChapterAction.skip) {
            final existingEpIds = conflict.existingChapters
                .map((chapter) => chapter.epId)
                .toSet();
            queuedTargets = queuedTargets
                .where((chapter) => !existingEpIds.contains(chapter.epId))
                .toList(growable: false);
          } else {
            await Future<void>.delayed(const Duration(milliseconds: 260));
            if (_disposed || !context.mounted) return;
          }
        }
        if (!hasUndownloadedChapters ||
            queuedTargets.length == downloadConflictTargets.length) {
          redownloadExisting = await showComicDetailDownloadConflictDialog(
            context,
            conflict: conflict,
            dialogTheme: _detailThemeApplier(Theme.of(context)),
          );
          if (!redownloadExisting || _disposed || !context.mounted) {
            return;
          }
        }
      }
      final result = await _repository.enqueueDownload(
        details: details,
        coverUrl: details.cover.trim().isNotEmpty
            ? details.cover
            : _comic.cover,
        description: details.description,
        chapters: queuedTargets,
        redownloadExisting: redownloadExisting,
      );
      if (_disposed || !context.mounted) return;
      if (result == MangaDownloadEnqueueResult.alreadyQueued) {
        unawaited(
          showHazukiPrompt(context, l10n(context).downloadsAlreadyInQueue),
        );
        return;
      }
      if (result == MangaDownloadEnqueueResult.nothingToQueue) {
        return;
      }
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
      showHazukiPrompt(
        context,
        l10n(context).downloadsQueued('${queuedTargets.length}'),
      ),
    );
  }

  Widget _wrapWithDetailTheme(BuildContext context, Widget child) {
    return Theme(data: _detailThemeApplier(Theme.of(context)), child: child);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
