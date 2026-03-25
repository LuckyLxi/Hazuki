part of '../main.dart';

class ComicDetailPage extends StatefulWidget {
  const ComicDetailPage({
    super.key,
    required this.comic,
    required this.heroTag,
  });

  final ExploreComic comic;
  final String heroTag;

  @override
  State<ComicDetailPage> createState() => _ComicDetailPageState();
}

class _ComicDetailPageState extends State<ComicDetailPage> {
  static const _mediaChannel = MethodChannel('hazuki.comics/media');

  late Future<ComicDetailsData> _future;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _actionButtonsKey = GlobalKey();
  final GlobalKey _favoriteRowKey = GlobalKey();
  final GlobalKey _headerTitleKey = GlobalKey();
  bool _favoriteBusy = false;
  bool? _favoriteOverride;
  bool _comicDynamicColorEnabled = false;
  ColorScheme? _lightComicScheme;
  ColorScheme? _darkComicScheme;
  final Map<String, Uint8List> _dynamicColorImageCache = <String, Uint8List>{};
  double _appBarSolidProgress = 0;
  bool _showCollapsedComicTitle = false;
  String _appBarComicTitle = '';
  String _appBarUpdateTime = '';
  Map<String, dynamic>? _lastReadProgress;

  @override
  void initState() {
    super.initState();
    _future = HazukiSourceService.instance
        .loadComicDetails(widget.comic.id)
        .timeout(const Duration(seconds: 30));
    _scrollController.addListener(_handleScroll);
    unawaited(_warmupReaderImages());
    unawaited(_loadDynamicColorSetting());
    unawaited(_loadReadingProgress());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _updateAppBarSolidProgress();
    });
    unawaited(_recordHistory());
  }

  Future<void> _loadReadingProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('reading_progress_${widget.comic.id}');
      if (jsonStr != null) {
        if (!mounted) return;
        setState(() {
          _lastReadProgress = jsonDecode(jsonStr);
        });
      }
    } catch (_) {}
  }

  Future<void> _recordHistory() async {
    try {
      final details = await _future;
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      var history = <Map<String, dynamic>>[];
      final jsonStr = prefs.getString('hazuki_read_history');
      if (jsonStr != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          history = jsonList.cast<Map<String, dynamic>>();
        } catch (_) {}
      }

      final comicId = details.id.trim().isNotEmpty
          ? details.id
          : widget.comic.id;
      final coverUrl = details.cover.trim().isNotEmpty
          ? details.cover
          : widget.comic.cover;

      // Remove existing to push to top
      history.removeWhere((e) => e['id'] == comicId);
      history.insert(0, {
        'id': comicId,
        'title': details.title.isNotEmpty ? details.title : widget.comic.title,
        'cover': coverUrl,
        'subTitle': details.subTitle.isNotEmpty
            ? details.subTitle
            : widget.comic.subTitle,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Optional: limit history size
      if (history.length > 70) {
        history = history.sublist(0, 70);
      }

      await prefs.setString('hazuki_read_history', jsonEncode(history));
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    _updateAppBarSolidProgress();
  }

  bool _updateAppBarSolidProgress() {
    if (!_scrollController.hasClients) {
      return false;
    }

    final offset = _scrollController.offset.clamp(0.0, double.infinity);
    const fadeStart = 72.0;
    const fadeDistance = 132.0;
    const titleCollapseOffset = 186.0;

    final nextProgress = ((offset - fadeStart) / fadeDistance).clamp(0.0, 1.0);
    final titleCollapsed = offset >= titleCollapseOffset;

    final progressChanged = (_appBarSolidProgress - nextProgress).abs() >= 0.02;
    final titleChanged = titleCollapsed != _showCollapsedComicTitle;

    if (!progressChanged && !titleChanged) {
      return false;
    }

    _appBarSolidProgress = nextProgress;
    _showCollapsedComicTitle = titleCollapsed;
    if (mounted) {
      setState(() {});
    }
    return true;
  }

  Future<void> _warmupReaderImages() async {
    if (hazukiNoImageModeNotifier.value) {
      return;
    }
    try {
      final details = await _future;
      if (details.chapters.isEmpty) {
        return;
      }
      final first = details.chapters.entries.first;
      final images = await HazukiSourceService.instance.loadChapterImages(
        comicId: details.id,
        epId: first.key,
      );
      await HazukiSourceService.instance.prefetchComicImages(
        comicId: details.id,
        epId: first.key,
        imageUrls: images,
        count: 3,
        memoryCount: 1,
      );
    } catch (_) {}
  }

  Future<void> _loadDynamicColorSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool('appearance_comic_detail_dynamic_color') ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _comicDynamicColorEnabled = enabled;
    });
    if (!enabled) return;
    unawaited(_scheduleDynamicColorExtraction());
  }

  Future<void> _scheduleDynamicColorExtraction() async {
    await Future.delayed(const Duration(milliseconds: 620));
    if (!mounted ||
        !_comicDynamicColorEnabled ||
        hazukiNoImageModeNotifier.value) {
      return;
    }
    final coverUrl = await _resolveDynamicColorCoverUrl();
    if (coverUrl.isEmpty || !mounted) {
      return;
    }
    unawaited(_extractColorScheme(coverUrl));
  }

  Future<String> _resolveDynamicColorCoverUrl() async {
    final coverUrl = widget.comic.cover.trim();
    if (coverUrl.isNotEmpty) {
      return coverUrl;
    }
    try {
      final details = await _future;
      final dCoverUrl = details.cover.trim();
      if (dCoverUrl.isNotEmpty) {
        return dCoverUrl;
      }
    } catch (_) {}
    return widget.comic.cover.trim();
  }

  Future<void> _extractColorScheme(String url) async {
    try {
      final cachedBytes = _dynamicColorImageCache[url];
      final bytes =
          cachedBytes ??
          await HazukiSourceService.instance.downloadImageBytes(
            url,
            keepInMemory: true,
          );
      if (!mounted) {
        return;
      }
      if (cachedBytes == null) {
        _dynamicColorImageCache[url] = bytes;
      }
      final imgProvider = MemoryImage(bytes);
      final light = await ColorScheme.fromImageProvider(
        provider: imgProvider,
        brightness: Brightness.light,
      );

      // 避免黑白封面取色退回到默认蓝色时错误覆盖应用主题。
      final fallbackLight = ColorScheme.fromSeed(
        seedColor: const Color(0xff4285F4),
        brightness: Brightness.light,
      );
      if (light.primary == fallbackLight.primary) {
        return;
      }

      final dark = await ColorScheme.fromImageProvider(
        provider: imgProvider,
        brightness: Brightness.dark,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lightComicScheme = light;
        _darkComicScheme = dark;
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite(ComicDetailsData details) async {
    if (_favoriteBusy) {
      return;
    }

    if (!HazukiSourceService.instance.isLogged) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).historyLoginRequired,
          isError: true,
        ),
      );
      return;
    }

    final service = HazukiSourceService.instance;
    if (!service.supportFavoriteFolderLoad || !service.supportFavoriteToggle) {
      final currentFavorite = _favoriteOverride ?? details.isFavorite;
      await _toggleFavoriteSimple(
        details: details,
        isAdding: !currentFavorite,
        folderId: '0',
      );
      return;
    }

    await _showFavoriteFoldersPanel(details);
  }

  Future<void> _toggleFavoriteSimple({
    required ComicDetailsData details,
    required bool isAdding,
    required String folderId,
  }) async {
    setState(() {
      _favoriteBusy = true;
    });
    try {
      await HazukiSourceService.instance.toggleFavorite(
        comicId: details.id,
        isAdding: isAdding,
        folderId: folderId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _favoriteOverride = isAdding;
      });
      unawaited(
        showHazukiPrompt(
          context,
          isAdding
              ? l10n(context).comicDetailFavoriteAdded
              : l10n(context).comicDetailFavoriteRemoved,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteActionFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _favoriteBusy = false;
        });
      }
    }
  }

  ThemeData _buildDetailTheme(ThemeData baseTheme) {
    var theme = baseTheme;
    if (!_comicDynamicColorEnabled) {
      return theme;
    }
    var scheme = theme.brightness == Brightness.light
        ? _lightComicScheme
        : _darkComicScheme;
    if (scheme == null) {
      return theme;
    }
    if (theme.brightness == Brightness.dark &&
        theme.scaffoldBackgroundColor == Colors.black) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainer: Colors.black,
        surfaceContainerLow: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerHigh: Colors.black,
        surfaceContainerHighest: Colors.black,
      );
      return theme.copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        cardColor: Colors.black,
        colorScheme: scheme,
      );
    }
    return theme.copyWith(colorScheme: scheme);
  }

  Future<void> _showFavoriteFoldersPanel(ComicDetailsData details) async {
    final service = HazukiSourceService.instance;
    final singleFolderOnly = service.favoriteSingleFolderForSingleComic;

    final changed = await showGeneralDialog<Map<String, Set<String>>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final themedData = _buildDetailTheme(Theme.of(context));
        return Theme(
          data: themedData,
          child: _FavoriteFoldersMorphDialog(
            details: details,
            singleFolderOnly: singleFolderOnly,
            favoriteOverride: _favoriteOverride,
            initialIsFavorite: details.isFavorite,
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
        final slide = Tween<Offset>(
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

    if (changed == null || !mounted) {
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

    setState(() {
      _favoriteBusy = true;
    });

    try {
      if (singleFolderOnly) {
        if (selectedResult.isEmpty) {
          await service.toggleFavorite(
            comicId: details.id,
            isAdding: false,
            folderId: initialFavoritedResult.firstOrNull ?? '0',
          );
          _favoriteOverride = false;
        } else {
          await service.toggleFavorite(
            comicId: details.id,
            isAdding: true,
            folderId: selectedResult.first,
          );
          _favoriteOverride = true;
        }
      } else {
        for (final folderId in addTargets) {
          await service.toggleFavorite(
            comicId: details.id,
            isAdding: true,
            folderId: folderId,
          );
        }
        for (final folderId in removeTargets) {
          await service.toggleFavorite(
            comicId: details.id,
            isAdding: false,
            folderId: folderId,
          );
        }
        _favoriteOverride = selectedResult.isNotEmpty;
      }

      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteSettingsUpdated,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteSettingsUpdateFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _favoriteBusy = false;
        });
      }
    }
  }

  void _showChaptersPanel(ComicDetailsData details) {
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

    Navigator.of(context).push(
      _SpringBottomSheetRoute(
        builder: (routeContext) {
          final themedData = _buildDetailTheme(Theme.of(routeContext));
          return Theme(
            data: themedData,
            child: _ChaptersPanelSheet(
              details: details,
              onDownloadConfirm: (selectedEpIds) {
                Navigator.of(routeContext).pop();
                unawaited(
                  _enqueueChapterDownloads(
                    details,
                    selectedEpIds: selectedEpIds,
                  ),
                );
              },
              onChapterTap: (epId, chapterTitle, index) {
                Navigator.of(routeContext).pop();
                unawaited(
                  _openReader(
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
      ),
    );
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
            title: entry.value,
            index: i,
          ),
        );
      }
    }
    if (targets.isEmpty) {
      return;
    }
    await MangaDownloadService.instance.enqueueDownload(
      details: details,
      coverUrl: details.cover.trim().isNotEmpty
          ? details.cover
          : widget.comic.cover,
      description: details.description,
      chapters: targets,
    );
    if (!mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        l10n(context).downloadsQueued('${targets.length}'),
      ),
    );
  }

  Future<void> _openReader(
    ComicDetailsData details, {
    String? epId,
    String? chapterTitle,
    int? chapterIndex,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final chapters = details.chapters;
    if (chapters.isEmpty) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailNoChapters,
          isError: true,
        ),
      );
      return;
    }

    // 确定初始章节，优先级：指定 epId > 阅读进度记忆 > 第一章。
    MapEntry<String, String>? initialEntry;
    int finalIndex = 0;

    // 检查是否存在有效的阅读进度记录。
    final bool hasMemory =
        _lastReadProgress != null &&
        chapters.containsKey(_lastReadProgress!['epId']) &&
        chapters.length > 1;

    if (epId != null && chapters.containsKey(epId)) {
      initialEntry = MapEntry(epId, chapters[epId]!);
      finalIndex = chapterIndex ?? chapters.keys.toList().indexOf(epId);
    } else if (hasMemory) {
      final memEpId = _lastReadProgress!['epId'] as String;
      initialEntry = MapEntry(memEpId, chapters[memEpId]!);
      finalIndex = _lastReadProgress!['index'] as int;
    } else {
      initialEntry = chapters.entries.first;
      finalIndex = 0;
    }

    final initialChapterTitle =
        (chapterTitle != null && chapterTitle.isNotEmpty)
        ? chapterTitle
        : initialEntry.value;

    await Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ReaderPage(
              title: details.title,
              chapterTitle: initialChapterTitle,
              comicId: details.id,
              epId: initialEntry!.key,
              chapterIndex: finalIndex,
              images: const [],
              comicTheme: _buildDetailTheme(Theme.of(context)),
            ),
          ),
        )
        .then((_) {
          FocusManager.instance.primaryFocus?.unfocus();
          // 从阅读器返回后重新加载进度，同步按钮文案。
          if (mounted) unawaited(_loadReadingProgress());
        });
  }

  Widget _buildDetailMetaSection(ComicDetailsData details) {
    final strings = l10n(context);
    final authorLabel = strings.comicDetailAuthor;
    final tagLabel = strings.comicDetailTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ComicDetailIdRow(
          id: details.id,
          onCopy: () async {
            final id = details.id.trim();
            if (id.isEmpty) {
              return;
            }
            await Clipboard.setData(ClipboardData(text: id));
            if (!mounted) {
              return;
            }
            unawaited(showHazukiPrompt(context, strings.comicDetailCopiedId));
          },
        ),
        _ComicDetailMetaRow(
          label: authorLabel,
          values: _normalizeComicMetaValues(
            details.tags.keys
                .where(_isComicAuthorKey)
                .expand((k) => details.tags[k] ?? const <String>[])
                .toList(),
            label: authorLabel,
          ),
          onValuePressed: (value) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SearchPage(initialKeyword: value),
              ),
            );
          },
          onValueLongPress: (value) async {
            unawaited(HapticFeedback.heavyImpact());
            await Clipboard.setData(ClipboardData(text: value));
            if (!mounted) {
              return;
            }
            unawaited(
              showHazukiPrompt(context, strings.comicDetailCopiedPrefix(value)),
            );
          },
        ),
        _ComicDetailMetaRow(
          label: tagLabel,
          values: _normalizeComicMetaValues(
            details.tags.entries
                .where(
                  (e) =>
                      !_isComicAuthorKey(e.key) &&
                      e.key != details.tags.keys.lastOrNull,
                )
                .expand((e) => e.value)
                .toList(),
            label: tagLabel,
          ),
          onValuePressed: (value) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SearchPage(initialKeyword: value),
              ),
            );
          },
          onValueLongPress: (value) async {
            unawaited(HapticFeedback.heavyImpact());
            await Clipboard.setData(ClipboardData(text: value));
            if (!mounted) {
              return;
            }
            unawaited(
              showHazukiPrompt(context, strings.comicDetailCopiedPrefix(value)),
            );
          },
        ),
      ],
    );
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
      final directory = Directory('/storage/emulated/0/Pictures/Hazuki');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await _mediaChannel.invokeMethod<bool>('scanFile', {'path': file.path});
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailSavedToPath(file.path),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _showCoverActions(String imageUrl) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return _ComicCoverActionsSheet(
          onSavePressed: () => unawaited(_saveImageToDownloads(imageUrl)),
        );
      },
    );
  }

  Future<void> _showCoverPreview(String imageUrl) async {
    final normalized = imageUrl.trim();
    if (normalized.isEmpty) {
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
          return _ComicCoverPreviewPage(
            imageUrl: normalized,
            heroTag: widget.heroTag,
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

  @override
  Widget build(BuildContext context) {
    final theme = _buildDetailTheme(Theme.of(context));
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final surface = theme.colorScheme.surface;

    return AnimatedTheme(
      data: theme,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: surface,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            titleSpacing: 0,
            title: _ComicDetailAppBarTitle(
              showCollapsedComicTitle: _showCollapsedComicTitle,
              appBarComicTitle: _appBarComicTitle,
              appBarUpdateTime: _appBarUpdateTime,
              theme: theme,
            ),
            backgroundColor: Color.lerp(
              Colors.transparent,
              surface,
              _appBarSolidProgress,
            ),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: Stack(
            children: [
              _ComicDetailParallaxBackground(
                scrollController: _scrollController,
                coverUrl: widget.comic.cover.trim(),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: surface.withValues(alpha: _appBarSolidProgress),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: topInset),
                child: _ComicDetailBody(
                  future: _future,
                  scrollController: _scrollController,
                  surface: surface,
                  heroTag: widget.heroTag,
                  comic: widget.comic,
                  headerTitleKey: _headerTitleKey,
                  favoriteRowKey: _favoriteRowKey,
                  actionButtonsKey: _actionButtonsKey,
                  favoriteBusy: _favoriteBusy,
                  favoriteOverride: _favoriteOverride,
                  lastReadProgress: _lastReadProgress,
                  buildViewsText: _extractComicViewsText,
                  buildMetaSection: _buildDetailMetaSection,
                  onShowCoverPreview: (imageUrl) =>
                      unawaited(_showCoverPreview(imageUrl)),
                  onFavoriteTap: _toggleFavorite,
                  onShowChapters: _showChaptersPanel,
                  onOpenReader: _openReader,
                  onDetailsResolved: ({required title, required updateTime}) {
                    _appBarComicTitle = title;
                    _appBarUpdateTime = updateTime;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _FavoriteDialogPhase { loading, result }

class _FavoriteFoldersMorphDialog extends StatefulWidget {
  const _FavoriteFoldersMorphDialog({
    required this.details,
    required this.singleFolderOnly,
    required this.favoriteOverride,
    required this.initialIsFavorite,
  });

  final ComicDetailsData details;
  final bool singleFolderOnly;
  final bool? favoriteOverride;
  final bool initialIsFavorite;

  @override
  State<_FavoriteFoldersMorphDialog> createState() =>
      _FavoriteFoldersMorphDialogState();
}

class _FavoriteFoldersMorphDialogState
    extends State<_FavoriteFoldersMorphDialog> {
  final HazukiSourceService _service = HazukiSourceService.instance;

  _FavoriteDialogPhase _phase = _FavoriteDialogPhase.loading;
  bool _busy = false;
  String? _loadError;
  List<FavoriteFolder> _folders = <FavoriteFolder>[];
  Set<String> _selected = <String>{};
  Set<String> _initialFavorited = <String>{};

  bool get _showExpandedDialog => _phase == _FavoriteDialogPhase.result;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFolders(initialLoad: true));
  }

  Future<void> _loadFolders({bool initialLoad = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      if (initialLoad) {
        _phase = _FavoriteDialogPhase.loading;
      } else {
        _busy = true;
      }
      _loadError = null;
    });

    try {
      final result = await _service.loadFavoriteFolders(
        comicId: widget.details.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _FavoriteDialogPhase.result;
        _busy = false;
        if (result.errorMessage != null) {
          _loadError = result.errorMessage;
          return;
        }
        final favorited = Set<String>.from(result.favoritedFolderIds);
        if (favorited.isEmpty &&
            widget.singleFolderOnly &&
            (widget.favoriteOverride ?? widget.initialIsFavorite)) {
          favorited.add('0');
        }
        _loadError = null;
        _folders = List<FavoriteFolder>.from(result.folders);
        _initialFavorited = favorited;
        _selected = Set<String>.from(favorited);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _FavoriteDialogPhase.result;
        _busy = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _addFolder() async {
    final strings = l10n(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(strings.comicDetailCreateFavoriteFolder),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: strings.comicDetailFavoriteFolderNameHint,
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(strings.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setDialogState(
                        () => errorText = strings
                            .comicDetailFavoriteFolderNameRequired,
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, text);
                  },
                  child: Text(strings.commonConfirm),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await _service.addFavoriteFolder(name);
      final refreshed = await _service.loadFavoriteFolders(
        comicId: widget.details.id,
      );
      if (refreshed.errorMessage != null) {
        throw Exception(refreshed.errorMessage);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _folders = List<FavoriteFolder>.from(refreshed.folders);
        _loadError = null;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
      unawaited(
        showHazukiPrompt(
          context,
          strings.comicDetailCreateFavoriteFolderFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    final strings = l10n(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(strings.comicDetailDeleteFavoriteFolder),
          content: Text(strings.comicDetailDeleteFavoriteFolderContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(strings.comicDetailDelete),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await _service.deleteFavoriteFolder(folderId);
      if (!mounted) {
        return;
      }
      setState(() {
        final deletedASelectedFolder =
            _selected.contains(folderId) || _initialFavorited.contains(folderId);
        final nextSelected = Set<String>.from(_selected)..remove(folderId);
        final nextInitialFavorited = Set<String>.from(_initialFavorited)
          ..remove(folderId);
        if (deletedASelectedFolder &&
            widget.singleFolderOnly &&
            nextSelected.isEmpty) {
          nextSelected.add('0');
        }
        if (deletedASelectedFolder &&
            widget.singleFolderOnly &&
            nextInitialFavorited.isEmpty) {
          nextInitialFavorited.add('0');
        }
        _folders = _folders.where((e) => e.id != folderId).toList();
        _selected = nextSelected;
        _initialFavorited = nextInitialFavorited;
        _loadError = null;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
      unawaited(
        showHazukiPrompt(
          context,
          strings.comicDetailDeleteFavoriteFolderFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  void _toggleFolder(String folderId, {bool? value}) {
    if (_busy) {
      return;
    }
    final checked = _selected.contains(folderId);
    final enable = value ?? !checked;
    setState(() {
      if (enable) {
        if (widget.singleFolderOnly) {
          _selected = <String>{folderId};
        } else {
          _selected = Set<String>.from(_selected)..add(folderId);
        }
      } else {
        _selected = Set<String>.from(_selected)..remove(folderId);
      }
    });
  }

  void _handleSave() {
    if (_busy || _loadError != null) {
      return;
    }
    if (_selected.isEmpty && _initialFavorited.isEmpty) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailSelectAtLeastOneFolder,
          isError: true,
        ),
      );
      return;
    }
    Navigator.of(context).pop(<String, Set<String>>{
      'selected': Set<String>.from(_selected),
      'initial': Set<String>.from(_initialFavorited),
    });
  }

  Widget _buildLoadingContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      key: const ValueKey('favorite_dialog_loading'),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const _ShapeMorphingLoader(size: 90),
          const SizedBox(height: 18),
          Text(
            l10n(context).commonLoading,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n(context).comicDetailManageFavorites,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStateCard({
    required Widget icon,
    required String message,
    required Color backgroundColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTile(BuildContext context, FavoriteFolder folder) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final checked = _selected.contains(folder.id);
    final title = folder.id == '0'
        ? l10n(context).favoriteAllFolder
        : folder.name;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: checked
            ? cs.primaryContainer.withValues(alpha: 0.88)
            : cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: checked
              ? cs.primary.withValues(alpha: 0.34)
              : cs.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 2,
          ),
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: checked ? cs.primary : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              checked ? Icons.check_rounded : Icons.add_rounded,
              size: 18,
              color: checked ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: folder.id != '0' && _service.supportFavoriteFolderDelete
              ? IconButton(
                  tooltip:
                      l10n(context).comicDetailDeleteFavoriteFolderTooltip,
                  onPressed: _busy ? null : () => _deleteFolder(folder.id),
                  icon: const Icon(Icons.delete_outline_rounded),
                )
              : null,
          onTap: () => _toggleFolder(folder.id),
        ),
      ),
    );
  }

  Widget _buildDialogBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loadError != null) {
      return _buildStateCard(
        icon: Icon(
          Icons.error_outline_rounded,
          size: 28,
          color: cs.error,
        ),
        message:
            l10n(context).comicDetailFavoriteFoldersLoadFailed('$_loadError'),
        backgroundColor: cs.errorContainer.withValues(alpha: 0.32),
      );
    }

    if (_folders.isEmpty) {
      return _buildStateCard(
        icon: Icon(
          Icons.folder_off_outlined,
          size: 28,
          color: cs.onSurfaceVariant,
        ),
        message: l10n(context).comicDetailNoFavoriteFolders,
        backgroundColor: cs.surfaceContainerLow.withValues(alpha: 0.72),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.min(MediaQuery.sizeOf(context).height * 0.38, 320),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(10),
          itemCount: _folders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _buildFolderTile(context, _folders[index]),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        return SizedBox(
          key: ValueKey<String>(
            _loadError == null
                ? 'favorite_dialog_loaded'
                : 'favorite_dialog_error',
          ),
          width: double.infinity,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: hasBoundedHeight ? constraints.maxHeight : 0,
            ),
            child: Column(
              mainAxisSize:
                  hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n(context).comicDetailManageFavorites,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_service.supportFavoriteFolderAdd && _loadError == null)
                      IconButton(
                        tooltip:
                            l10n(context).comicDetailCreateFavoriteFolderTooltip,
                        onPressed: _busy ? null : _addFolder,
                        icon: const Icon(Icons.create_new_folder_outlined),
                      ),
                    IconButton(
                      tooltip: l10n(context).commonClose,
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  widget.singleFolderOnly
                      ? l10n(context).comicDetailSingleFolderHint
                      : l10n(context).comicDetailMultipleFoldersHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDialogBody(context),
                if (hasBoundedHeight)
                  const Spacer()
                else
                  const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _busy ? null : () => Navigator.of(context).pop(),
                        child: Text(l10n(context).commonClose),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : _loadError != null
                            ? () => unawaited(_loadFolders())
                            : _handleSave,
                        child: Text(
                          _loadError != null
                              ? l10n(context).commonRetry
                              : l10n(context).commonSave,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBusyOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: cs.surface.withValues(alpha: 0.72),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _ShapeMorphingLoader(size: 54),
                const SizedBox(height: 12),
                Text(
                  l10n(context).commonLoading,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final expanded = _showExpandedDialog;
    final dialogWidth = expanded
        ? math.min(size.width * 0.9, 440.0)
        : math.min(size.width * 0.78, 320.0);

    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeInOutCubicEmphasized,
              width: dialogWidth,
              constraints: BoxConstraints(
                minHeight: expanded ? 340 : 196,
                maxHeight: expanded ? size.height * 0.82 : 220,
              ),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(expanded ? 32 : 28),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: expanded ? 0.24 : 0.16,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: expanded ? 30 : 22,
                    spreadRadius: -6,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      expanded ? 20 : 24,
                      24,
                      expanded ? 20 : 24,
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 460),
                      curve: Curves.easeInOutCubicEmphasized,
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child: expanded
                            ? _buildExpandedContent(context)
                            : _buildLoadingContent(context),
                      ),
                    ),
                  ),
                  if (_busy && expanded) _buildBusyOverlay(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShapeMorphingLoader extends StatefulWidget {
  const _ShapeMorphingLoader({this.size = 84});

  final double size;

  @override
  State<_ShapeMorphingLoader> createState() => _ShapeMorphingLoaderState();
}

class _ShapeMorphingLoaderState extends State<_ShapeMorphingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ShapeMorphingLoaderPainter(
                progress: _controller.value,
                primary: cs.primary,
                secondary: cs.tertiary,
                highlight: cs.surfaceContainerHighest,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShapeMorphingLoaderPainter extends CustomPainter {
  const _ShapeMorphingLoaderPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.highlight,
  });

  final double progress;
  final Color primary;
  final Color secondary;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide;
    final phase = progress * math.pi * 2;
    final waveA = (math.sin(phase) + 1) / 2;
    final waveB = (math.sin(phase + math.pi / 2) + 1) / 2;
    final waveC = (math.sin(phase - math.pi / 3) + 1) / 2;

    final width = base * (0.44 + 0.22 * waveA);
    final height = base * (0.44 + 0.22 * waveB);
    final radius = base * (0.1 + 0.18 * waveC);
    final rotation = math.sin(phase - 0.8) * 0.42;
    final rect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawPath(
      path.shift(const Offset(0, 8)),
      Paint()
        ..color = primary.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(primary, secondary, 0.18)!,
            Color.lerp(primary, secondary, 0.72)!,
          ],
        ).createShader(rect),
    );

    final highlightRect = Rect.fromCenter(
      center: center.translate(-width * 0.12, -height * 0.16),
      width: width * (0.34 + 0.08 * waveB),
      height: height * (0.18 + 0.06 * waveA),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        highlightRect,
        Radius.circular(highlightRect.height),
      ),
      Paint()..color = highlight.withValues(alpha: 0.42),
    );

    final orbitDistance = base * 0.22;
    final orbitRadius = base * (0.07 + 0.015 * waveC);
    final orbitCenter = center.translate(
      math.cos(phase * 1.4 - math.pi / 3) * orbitDistance,
      math.sin(phase * 1.4 - math.pi / 3) * orbitDistance,
    );
    canvas.drawCircle(
      orbitCenter,
      orbitRadius,
      Paint()..color = secondary.withValues(alpha: 0.86),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShapeMorphingLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.highlight != highlight;
  }
}
