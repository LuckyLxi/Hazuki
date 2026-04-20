// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/app/chapter_title_resolver.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/manga_download_service.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

import 'comic_detail_controller_support.dart';

class ComicDetailActionsController {
  ComicDetailActionsController({
    required ComicDetailContextGetter contextGetter,
    required ComicDetailIsMounted isMounted,
    required ComicDetailStateUpdate updateState,
    required ExploreComic Function() comicGetter,
    required String Function() heroTagGetter,
    required ComicDetailThemeApplier detailThemeApplier,
    required Map<String, dynamic>? Function() lastReadProgressGetter,
    required Future<void> Function() reloadReadingProgress,
    required ComicDetailCoverPreviewPageBuilder coverPreviewPageBuilder,
    required ComicDetailFavoriteDialogBuilder favoriteDialogBuilder,
    required ComicDetailChaptersPanelBuilder chaptersPanelBuilder,
    required ComicDetailReaderPageBuilder readerPageBuilder,
    required ComicDetailSearchPageBuilder searchPageBuilder,
    required MethodChannel mediaChannel,
  }) : _contextGetter = contextGetter,
       _isMounted = isMounted,
       _updateState = updateState,
       _comicGetter = comicGetter,
       _heroTagGetter = heroTagGetter,
       _detailThemeApplier = detailThemeApplier,
       _lastReadProgressGetter = lastReadProgressGetter,
       _reloadReadingProgress = reloadReadingProgress,
       _coverPreviewPageBuilder = coverPreviewPageBuilder,
       _favoriteDialogBuilder = favoriteDialogBuilder,
       _chaptersPanelBuilder = chaptersPanelBuilder,
       _readerPageBuilder = readerPageBuilder,
       _searchPageBuilder = searchPageBuilder,
       _mediaChannel = mediaChannel;

  final ComicDetailContextGetter _contextGetter;
  final ComicDetailIsMounted _isMounted;
  final ComicDetailStateUpdate _updateState;
  final ExploreComic Function() _comicGetter;
  final String Function() _heroTagGetter;
  final ComicDetailThemeApplier _detailThemeApplier;
  final Map<String, dynamic>? Function() _lastReadProgressGetter;
  final Future<void> Function() _reloadReadingProgress;
  final ComicDetailCoverPreviewPageBuilder _coverPreviewPageBuilder;
  final ComicDetailFavoriteDialogBuilder _favoriteDialogBuilder;
  final ComicDetailChaptersPanelBuilder _chaptersPanelBuilder;
  final ComicDetailReaderPageBuilder _readerPageBuilder;
  final ComicDetailSearchPageBuilder _searchPageBuilder;
  final MethodChannel _mediaChannel;

  bool _favoriteBusy = false;
  bool? _favoriteOverride;
  bool? _cloudFavoriteOverride;

  BuildContext get _context => _contextGetter();

  bool get favoriteBusy => _favoriteBusy;
  bool? get favoriteOverride => _favoriteOverride;
  bool? get cloudFavoriteOverride => _cloudFavoriteOverride;

  void applyInitialFavoriteOverrides({
    required bool favoriteOverride,
    required bool cloudFavoriteOverride,
  }) {
    if (!_isMounted()) {
      return;
    }
    _updateState(() {
      _favoriteOverride = favoriteOverride;
      _cloudFavoriteOverride = cloudFavoriteOverride;
    });
  }

  Future<void> showCoverPreview(String imageUrl) async {
    final normalized = imageUrl.trim();
    if (normalized.isEmpty) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    await Navigator.of(_context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black45,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _coverPreviewPageBuilder(
            imageUrl: normalized,
            heroTag: _heroTagGetter(),
            onLongPress: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(_showCoverActions(normalized));
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

  Future<void> toggleFavorite(ComicDetailsData details) async {
    if (_favoriteBusy) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await _showFavoriteFoldersPanel(details);
  }

  void showChaptersPanel(ComicDetailsData details) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (details.chapters.isEmpty) {
      unawaited(
        showHazukiPrompt(
          _context,
          l10n(_context).comicDetailNoChapterInfo,
          isError: true,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: _context,
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
        final themedData = _detailThemeApplier(Theme.of(routeContext));
        return Theme(
          data: themedData,
          child: _chaptersPanelBuilder(
            details: details,
            themedData: themedData,
            onDownloadConfirm: (selectedEpIds) {
              Navigator.of(routeContext).pop();
              unawaited(
                _enqueueChapterDownloads(details, selectedEpIds: selectedEpIds),
              );
            },
            onChapterTap: (epId, chapterTitle, index) {
              Navigator.of(routeContext).pop();
              unawaited(
                openReader(
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
    ComicDetailsData details, {
    String? epId,
    String? chapterTitle,
    int? chapterIndex,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final chapters = details.chapters;
    if (chapters.isEmpty) {
      if (!_isMounted()) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          _context,
          l10n(_context).comicDetailNoChapters,
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
      _context,
      (chapterTitle != null && chapterTitle.isNotEmpty)
          ? chapterTitle
          : initialEntry.value,
    );

    await Navigator.of(_context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => _readerPageBuilder(
              details: details,
              chapterTitle: initialChapterTitle,
              epId: initialEntry!.key,
              chapterIndex: finalIndex,
              comicTheme: _detailThemeApplier(Theme.of(_context)),
            ),
          ),
        )
        .then((_) {
          FocusManager.instance.primaryFocus?.unfocus();
          if (_isMounted()) {
            unawaited(_reloadReadingProgress());
          }
        });
  }

  Future<void> copyComicId(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: trimmedId));
    if (!_isMounted()) {
      return;
    }
    unawaited(showHazukiPrompt(_context, l10n(_context).comicDetailCopiedId));
  }

  void openSearchForKeyword(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return;
    }
    _openSearchForKeyword(trimmedValue);
  }

  Future<void> copyMetaValue(String value) async {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return;
    }
    await _copyMetaValue(trimmedValue);
  }

  Future<void> _saveImageToDownloads(String imageUrl) async {
    try {
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        imageUrl,
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
      if (!_isMounted()) {
        return;
      }
      unawaited(
        showHazukiPrompt(_context, l10n(_context).comicDetailSavedToPath),
      );
    } catch (e) {
      if (!_isMounted()) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          _context,
          l10n(_context).comicDetailSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _showCoverActions(String imageUrl) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final themedData = _detailThemeApplier(Theme.of(_context));
    await showGeneralDialog<void>(
      context: _context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Theme(
          data: themedData,
          child: AlertDialog(
            title: Text(l10n(_context).comicDetailSaveImage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n(_context).commonCancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_saveImageToDownloads(imageUrl));
                },
                child: Text(l10n(_context).commonSave),
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

  Future<void> _showFavoriteFoldersPanel(ComicDetailsData details) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final service = HazukiSourceService.instance;
    final singleFolderOnly = service.favoriteSingleFolderForSingleComic;

    final changed = await showGeneralDialog<Map<String, Set<String>>>(
      context: _context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(_context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final themedData = _detailThemeApplier(Theme.of(_context));
        return Theme(
          data: themedData,
          child: _favoriteDialogBuilder(
            details: details,
            singleFolderOnly: singleFolderOnly,
            cloudFavoriteOverride: _cloudFavoriteOverride,
            initialIsFavorite: details.isFavorite,
            themedData: themedData,
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final opacity = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide =
            Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            );
        return FadeTransition(
          opacity: opacity,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(scale),
              child: child,
            ),
          ),
        );
      },
    );

    if (changed == null || !_isMounted()) {
      return;
    }

    final selectedResult = Set<String>.from(changed['selected'] ?? <String>{});
    final initialFavoritedResult = Set<String>.from(
      changed['initial'] ?? <String>{},
    );

    final addTargets = selectedResult.difference(initialFavoritedResult);
    final removeTargets = initialFavoritedResult.difference(selectedResult);

    if (addTargets.isEmpty && removeTargets.isEmpty) {
      return;
    }

    _updateState(() {
      _favoriteBusy = true;
    });

    try {
      await _applyFavoriteSelectionChanges(
        details: details,
        selectedResult: selectedResult,
        initialFavoritedResult: initialFavoritedResult,
        singleFolderOnly: singleFolderOnly,
      );

      if (!_isMounted()) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          _context,
          l10n(_context).comicDetailFavoriteSettingsUpdated,
        ),
      );
    } catch (e) {
      if (!_isMounted()) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          _context,
          l10n(_context).comicDetailFavoriteSettingsUpdateFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (_isMounted()) {
        _updateState(() {
          _favoriteBusy = false;
        });
      }
    }
  }

  Future<void> _applyFavoriteSelectionChanges({
    required ComicDetailsData details,
    required Set<String> selectedResult,
    required Set<String> initialFavoritedResult,
    required bool singleFolderOnly,
  }) async {
    final service = HazukiSourceService.instance;
    final localService = LocalFavoritesService.instance;
    final selectedHandles = _favoriteHandlesFromStorageKeys(selectedResult);
    final initialHandles = _favoriteHandlesFromStorageKeys(
      initialFavoritedResult,
    );

    final selectedCloudIds = _folderIdsForSource(
      selectedHandles,
      FavoriteFolderSource.cloud,
    );
    final initialCloudIds = _folderIdsForSource(
      initialHandles,
      FavoriteFolderSource.cloud,
    );
    final selectedLocalIds = _folderIdsForSource(
      selectedHandles,
      FavoriteFolderSource.local,
    );
    final initialLocalIds = _folderIdsForSource(
      initialHandles,
      FavoriteFolderSource.local,
    );

    if (singleFolderOnly && service.isLogged && service.supportFavoriteToggle) {
      if (selectedCloudIds.isEmpty && initialCloudIds.isNotEmpty) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: false,
          folderId: initialCloudIds.first,
        );
      } else if (selectedCloudIds.isNotEmpty &&
          !_setContentsEqual(selectedCloudIds, initialCloudIds)) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: true,
          folderId: selectedCloudIds.first,
        );
      }
    } else if (service.isLogged && service.supportFavoriteToggle) {
      final addCloudIds = selectedCloudIds.difference(initialCloudIds);
      final removeCloudIds = initialCloudIds.difference(selectedCloudIds);
      for (final folderId in addCloudIds) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: true,
          folderId: folderId,
        );
      }
      for (final folderId in removeCloudIds) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: false,
          folderId: folderId,
        );
      }
    }

    final addLocalIds = selectedLocalIds.difference(initialLocalIds);
    final removeLocalIds = initialLocalIds.difference(selectedLocalIds);
    for (final folderId in addLocalIds) {
      await localService.toggleFavorite(
        details: details,
        isAdding: true,
        folderId: folderId,
      );
    }
    for (final folderId in removeLocalIds) {
      await localService.toggleFavorite(
        details: details,
        isAdding: false,
        folderId: folderId,
      );
    }

    _updateState(() {
      _favoriteOverride = selectedResult.isNotEmpty;
      _cloudFavoriteOverride = selectedCloudIds.isNotEmpty;
    });
  }

  Set<FavoriteFolderHandle> _favoriteHandlesFromStorageKeys(Set<String> keys) {
    final handles = <FavoriteFolderHandle>{};
    for (final key in keys) {
      final handle = favoriteFolderHandleFromStorageKey(key);
      if (handle != null) {
        handles.add(handle);
      }
    }
    return handles;
  }

  Set<String> _folderIdsForSource(
    Set<FavoriteFolderHandle> handles,
    FavoriteFolderSource source,
  ) {
    return handles
        .where((handle) => handle.source == source)
        .map((handle) => handle.id)
        .toSet();
  }

  Future<void> _enqueueChapterDownloads(
    ComicDetailsData details, {
    required Set<String> selectedEpIds,
  }) async {
    if (selectedEpIds.isEmpty) {
      return;
    }
    final targets = <MangaChapterDownloadTarget>[];
    for (var i = 0; i < details.chapters.length; i++) {
      final entry = details.chapters.entries.elementAt(i);
      if (selectedEpIds.contains(entry.key)) {
        targets.add(
          MangaChapterDownloadTarget(
            epId: entry.key,
            title: resolveHazukiChapterTitle(_context, entry.value),
            index: i,
          ),
        );
      }
    }
    if (targets.isEmpty) {
      return;
    }
    final comic = _comicGetter();
    await MangaDownloadService.instance.enqueueDownload(
      details: details,
      coverUrl: details.cover.trim().isNotEmpty ? details.cover : comic.cover,
      description: details.description,
      chapters: targets,
    );
    if (!_isMounted()) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        _context,
        l10n(_context).downloadsQueued('${targets.length}'),
      ),
    );
  }

  bool _setContentsEqual(Set<String> left, Set<String> right) {
    return left.length == right.length && left.containsAll(right);
  }

  void _openSearchForKeyword(String value) {
    Navigator.of(
      _context,
    ).push(MaterialPageRoute<void>(builder: (_) => _searchPageBuilder(value)));
  }

  Future<void> _copyMetaValue(String value) async {
    unawaited(HapticFeedback.heavyImpact());
    await Clipboard.setData(ClipboardData(text: value));
    if (!_isMounted()) {
      return;
    }
    unawaited(
      showHazukiPrompt(_context, l10n(_context).comicDetailCopiedPrefix(value)),
    );
  }
}
