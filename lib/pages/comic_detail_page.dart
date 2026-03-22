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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n(context).historyLoginRequired)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAdding
                ? l10n(context).comicDetailFavoriteAdded
                : l10n(context).comicDetailFavoriteRemoved,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n(context).comicDetailFavoriteActionFailed('$e')),
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

    var hasRequestedInitialLoad = false;
    var isLoading = true;
    var loadedAnimationPlayed = false;
    String? loadError;
    List<FavoriteFolder> folders = <FavoriteFolder>[];
    Set<String> selected = <String>{};
    Set<String> initialFavorited = <String>{};

    final changed = await showModalBottomSheet<Map<String, Set<String>>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final themedData = _buildDetailTheme(Theme.of(sheetContext));

        return Theme(
          data: themedData,
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> loadFolders() async {
                try {
                  final result = await service.loadFavoriteFolders(
                    comicId: details.id,
                  );
                  if (!sheetContext.mounted) {
                    return;
                  }
                  setSheetState(() {
                    isLoading = false;
                    if (result.errorMessage != null) {
                      loadError = result.errorMessage;
                      return;
                    }
                    loadError = null;
                    loadedAnimationPlayed = true;
                    folders = List<FavoriteFolder>.from(result.folders);
                    initialFavorited = Set<String>.from(
                      result.favoritedFolderIds,
                    );
                    selected = Set<String>.from(initialFavorited);
                    if (selected.isEmpty &&
                        (_favoriteOverride ?? details.isFavorite)) {
                      selected = <String>{'0'};
                    }
                  });
                } catch (e) {
                  if (!sheetContext.mounted) {
                    return;
                  }
                  setSheetState(() {
                    isLoading = false;
                    loadError = e.toString();
                  });
                }
              }

              if (!hasRequestedInitialLoad) {
                hasRequestedInitialLoad = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!sheetContext.mounted) {
                    return;
                  }
                  unawaited(loadFolders());
                });
              }

              Future<void> addFolder() async {
                final controller = TextEditingController();
                final strings = l10n(context);
                final name = await showDialog<String>(
                  context: sheetContext,
                  builder: (dialogContext) {
                    String? errorText;
                    return Theme(
                      data: themedData,
                      child: StatefulBuilder(
                        builder: (dialogContext, setDialogState) {
                          return AlertDialog(
                            title: Text(
                              strings.comicDetailCreateFavoriteFolder,
                            ),
                            content: TextField(
                              controller: controller,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText:
                                    strings.comicDetailFavoriteFolderNameHint,
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
                      ),
                    );
                  },
                );
                controller.dispose();
                if (name == null || name.isEmpty) {
                  return;
                }
                try {
                  setSheetState(() => isLoading = true);
                  await service.addFavoriteFolder(name);
                  final refreshed = await service.loadFavoriteFolders(
                    comicId: details.id,
                  );
                  if (refreshed.errorMessage != null) {
                    throw Exception(refreshed.errorMessage);
                  }
                  if (!sheetContext.mounted) {
                    return;
                  }
                  setSheetState(() {
                    folders = List<FavoriteFolder>.from(refreshed.folders);
                    isLoading = false;
                    loadError = null;
                  });
                } catch (e) {
                  if (!sheetContext.mounted) {
                    return;
                  }
                  setSheetState(() => isLoading = false);
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.comicDetailCreateFavoriteFolderFailed('$e'),
                      ),
                    ),
                  );
                }
              }

              Future<void> deleteFolder(String folderId) async {
                final strings = l10n(context);
                final ok = await showDialog<bool>(
                  context: sheetContext,
                  builder: (dialogContext) {
                    return Theme(
                      data: themedData,
                      child: AlertDialog(
                        title: Text(strings.comicDetailDeleteFavoriteFolder),
                        content: Text(
                          strings.comicDetailDeleteFavoriteFolderContent,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: Text(strings.commonCancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: Text(strings.comicDetailDelete),
                          ),
                        ],
                      ),
                    );
                  },
                );
                if (ok != true) {
                  return;
                }
                try {
                  setSheetState(() => isLoading = true);
                  await service.deleteFavoriteFolder(folderId);
                  if (!sheetContext.mounted) {
                    return;
                  }
                  setSheetState(() {
                    folders = folders.where((e) => e.id != folderId).toList();
                    selected.remove(folderId);
                    initialFavorited.remove(folderId);
                    isLoading = false;
                    loadError = null;
                  });
                } catch (e) {
                  if (!sheetContext.mounted) {
                    return;
                  }
                  setSheetState(() => isLoading = false);
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.comicDetailDeleteFavoriteFolderFailed('$e'),
                      ),
                    ),
                  );
                }
              }

              Widget buildLoadingBody() {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HazukiStickerLoadingIndicator(size: 112),
                        const SizedBox(height: 10),
                        Text(l10n(context).commonLoading),
                      ],
                    ),
                  ),
                );
              }

              Widget buildLoadedBody() {
                if (loadError != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n(
                          context,
                        ).comicDetailFavoriteFoldersLoadFailed('$loadError'),
                        style: TextStyle(
                          color: Theme.of(sheetContext).colorScheme.error,
                        ),
                      ),
                    ),
                  );
                }

                if (folders.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n(context).comicDetailNoFavoriteFolders),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.48,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (itemContext, index) {
                      final folder = folders[index];
                      final checked = selected.contains(folder.id);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        title: Text(folder.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: checked,
                              onChanged: (value) {
                                setSheetState(() {
                                  final enabled = value == true;
                                  if (enabled) {
                                    if (singleFolderOnly) {
                                      selected = <String>{folder.id};
                                    } else {
                                      selected.add(folder.id);
                                    }
                                  } else {
                                    selected.remove(folder.id);
                                  }
                                });
                              },
                            ),
                            if (folder.id != '0' &&
                                service.supportFavoriteFolderDelete)
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: l10n(
                                  context,
                                ).comicDetailDeleteFavoriteFolderTooltip,
                                onPressed: () => deleteFolder(folder.id),
                              ),
                          ],
                        ),
                        onTap: () {
                          setSheetState(() {
                            if (singleFolderOnly) {
                              selected = <String>{folder.id};
                            } else if (checked) {
                              selected.remove(folder.id);
                            } else {
                              selected.add(folder.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                );
              }

              Widget buildAnimatedBody() {
                final showLoadingBody = isLoading && !loadedAnimationPlayed;
                return TweenAnimationBuilder<double>(
                  key: ValueKey(
                    showLoadingBody
                        ? 'favorite_loading_body'
                        : 'favorite_loaded_body',
                  ),
                  tween: Tween<double>(begin: 0.94, end: 1),
                  duration: Duration(milliseconds: showLoadingBody ? 160 : 320),
                  curve: showLoadingBody
                      ? Curves.easeOutCubic
                      : Curves.easeOutBack,
                  builder: (context, value, child) {
                    final opacity = showLoadingBody
                        ? 1.0
                        : ((value - 0.94) / 0.06).clamp(0.0, 1.0);
                    final translateY = (1 - value) * 28;
                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, translateY),
                        child: Transform.scale(
                          scale: value,
                          alignment: Alignment.topCenter,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: showLoadingBody
                      ? buildLoadingBody()
                      : buildLoadedBody(),
                );
              }

              final showLoadedState =
                  !isLoading && loadError == null && loadedAnimationPlayed;

              return SafeArea(
                child: AnimatedScale(
                  scale: showLoadedState ? 1 : 0.98,
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: showLoadedState ? 1 : 0.88,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: showLoadedState ? 24 : 10,
                            spreadRadius: showLoadedState ? 0 : -2,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 4,
                          bottom:
                              MediaQuery.of(sheetContext).viewInsets.bottom +
                              16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n(context).comicDetailManageFavorites,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (service.supportFavoriteFolderAdd &&
                                    !isLoading &&
                                    loadError == null)
                                  IconButton(
                                    tooltip: l10n(
                                      context,
                                    ).comicDetailCreateFavoriteFolderTooltip,
                                    onPressed: addFolder,
                                    icon: const Icon(
                                      Icons.create_new_folder_outlined,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              singleFolderOnly
                                  ? l10n(context).comicDetailSingleFolderHint
                                  : l10n(
                                      context,
                                    ).comicDetailMultipleFoldersHint,
                              style: Theme.of(sheetContext).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            buildAnimatedBody(),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: (isLoading || loadError != null)
                                  ? null
                                  : () {
                                      if (selected.isEmpty &&
                                          initialFavorited.isEmpty) {
                                        ScaffoldMessenger.of(
                                          sheetContext,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10n(
                                                context,
                                              ).comicDetailSelectAtLeastOneFolder,
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      Navigator.of(
                                        sheetContext,
                                      ).pop(<String, Set<String>>{
                                        'selected': Set<String>.from(selected),
                                        'initial': Set<String>.from(
                                          initialFavorited,
                                        ),
                                      });
                                    },
                              child: Text(l10n(context).commonSave),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n(context).comicDetailFavoriteSettingsUpdated),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n(context).comicDetailFavoriteSettingsUpdateFailed('$e'),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n(context).comicDetailNoChapterInfo)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n(context).comicDetailNoChapters)),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.comicDetailCopiedId)),
            );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.comicDetailCopiedPrefix(value))),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.comicDetailCopiedPrefix(value))),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n(context).comicDetailSavedToPath(file.path)),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n(context).comicDetailSaveFailed('$e'))),
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
