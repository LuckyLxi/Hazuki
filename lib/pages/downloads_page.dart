part of '../main.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage>
    with SingleTickerProviderStateMixin {
  late final Future<void> _initFuture;
  late final TabController _tabController;
  final Set<String> _selectedComicIds = <String>{};
  bool _selectionEnabled = false;
  bool _scanningDownloaded = false;

  bool get _selectionMode =>
      _tabController.index == 1 &&
      (_selectionEnabled || _selectedComicIds.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _initFuture = MangaDownloadService.instance.ensureInitialized();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!mounted || _tabController.indexIsChanging) {
      return;
    }
    setState(() {
      if (_tabController.index != 1) {
        _selectionEnabled = false;
        _selectedComicIds.clear();
      }
    });
  }

  Future<bool?> _showAnimatedDeleteDialog({
    required String title,
    required String content,
  }) {
    final strings = l10n(context);
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
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
  }

  Future<void> _deleteSelected() async {
    if (_selectedComicIds.isEmpty) {
      return;
    }
    final strings = l10n(context);
    final confirmed = await _showAnimatedDeleteDialog(
      title: strings.downloadsDeleteSelectedTitle,
      content: strings.downloadsDeleteSelectedContent(
        '${_selectedComicIds.length}',
      ),
    );
    if (confirmed != true) {
      return;
    }
    await MangaDownloadService.instance.deleteDownloadedComics(_selectedComicIds);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionEnabled = false;
      _selectedComicIds.clear();
    });
  }

  Future<void> _deleteSingleComic(DownloadedMangaComic comic) async {
    final strings = l10n(context);
    final confirmed = await _showAnimatedDeleteDialog(
      title: strings.downloadsDeleteSelectedTitle,
      content: strings.downloadsDeleteSelectedContent('1'),
    );
    if (confirmed != true) {
      return;
    }
    await MangaDownloadService.instance.deleteDownloadedComics([comic.comicId]);
  }

  Future<void> _pauseTask(String comicId) async {
    await MangaDownloadService.instance.pauseTask(comicId);
  }

  Future<void> _resumeTask(String comicId) async {
    await MangaDownloadService.instance.resumeTask(comicId);
  }

  Future<void> _deleteTask(String comicId) async {
    final strings = l10n(context);
    final confirmed = await _showAnimatedDeleteDialog(
      title: strings.comicDetailDelete,
      content: strings.downloadsDeleteSelectedContent('1'),
    );
    if (confirmed != true) {
      return;
    }
    await MangaDownloadService.instance.deleteTask(comicId);
  }

  void _toggleSelection(String comicId) {
    setState(() {
      if (_selectedComicIds.contains(comicId)) {
        _selectedComicIds.remove(comicId);
      } else {
        _selectedComicIds.add(comicId);
      }
    });
  }

  Future<void> _scanDownloadedComics() async {
    if (_scanningDownloaded) {
      return;
    }
    setState(() {
      _scanningDownloaded = true;
    });
    try {
      final result = await MangaDownloadService.instance.scanDownloadedComics();
      if (!mounted) {
        return;
      }
      final strings = l10n(context);
      final message = !result.permissionGranted
          ? strings.downloadsScanPermissionDenied
          : result.recoveredComics > 0
          ? strings.downloadsScanCompleted(
              result.scannedDirectories,
              result.recoveredComics,
            )
          : strings.downloadsScanNoRecoverable;
      await showHazukiPrompt(context, message);
    } catch (e) {
      if (!mounted) {
        return;
      }
      final strings = l10n(context);
      await showHazukiPrompt(context, strings.downloadsScanFailed('$e'));
    } finally {
      if (mounted) {
        setState(() {
          _scanningDownloaded = false;
        });
      }
    }
  }

  Widget? _buildScanButton(bool ready) {
    if (!ready || _tabController.index != 1 || _selectionMode) {
      return null;
    }
    final strings = l10n(context);
    return FloatingActionButton(
      tooltip: strings.downloadsScanTooltip,
      onPressed: _scanningDownloaded ? null : _scanDownloadedComics,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _scanningDownloaded
            ? SizedBox(
                key: const ValueKey<String>('scan_loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              )
            : const Icon(
                Icons.manage_search_rounded,
                key: ValueKey<String>('scan_icon'),
              ),
      ),
    );
  }

  Widget _buildAnimatedAppBarTitle(AppLocalizations strings) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.18),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          _selectionMode
              ? strings.downloadsSelectionTitle('${_selectedComicIds.length}')
              : strings.downloadsTitle,
          key: ValueKey<String>(
            _selectionMode
                ? 'selection_${_selectedComicIds.length}_${_tabController.index}'
                : 'title_${_tabController.index}',
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadedActions(AppLocalizations strings) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerRight,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            axis: Axis.horizontal,
            axisAlignment: 1,
            sizeFactor: animation,
            child: child,
          ),
        );
      },
      child: _tabController.index == 1
          ? Padding(
              key: const ValueKey<String>('download_actions_visible'),
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: kMinInteractiveDimension,
                    child: IconButton(
                      tooltip: _selectionMode
                          ? strings.commonClose
                          : strings.downloadsActionSelect,
                      onPressed: () {
                        setState(() {
                          if (_selectionMode) {
                            _selectionEnabled = false;
                            _selectedComicIds.clear();
                          } else {
                            _selectionEnabled = true;
                          }
                        });
                      },
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.86,
                                end: 1,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          _selectionMode ? Icons.close : Icons.checklist_rounded,
                          key: ValueKey<String>(
                            _selectionMode
                                ? 'selection_close_icon'
                                : 'selection_checklist_icon',
                          ),
                        ),
                      ),
                    ),
                  ),
                  ClipRect(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.centerRight,
                      widthFactor: _selectionMode ? 1 : 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOutCubic,
                        opacity: _selectionMode ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !_selectionMode,
                          child: SizedBox.square(
                            dimension: kMinInteractiveDimension,
                            child: IconButton(
                              tooltip: strings.comicDetailDelete,
                              onPressed: _deleteSelected,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey<String>('download_actions_hidden')),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations strings) {
    return hazukiFrostedAppBar(
      context: context,
      title: _buildAnimatedAppBarTitle(strings),
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: strings.downloadsTabOngoing),
          Tab(text: strings.downloadsTabDownloaded),
        ],
      ),
      actions: [_buildDownloadedActions(strings)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        return Scaffold(
          appBar: _buildAppBar(strings),
          floatingActionButton: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.86, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child:
                _buildScanButton(ready) ??
                const SizedBox.shrink(key: ValueKey<String>('scan_hidden')),
          ),
          body: !ready
              ? const Center(child: CircularProgressIndicator())
              : AnimatedBuilder(
                  animation: MangaDownloadService.instance,
                  builder: (context, _) {
                    final tasks = MangaDownloadService.instance.tasks;
                    final comics = MangaDownloadService.instance.downloadedComics;
                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _DownloadsOngoingTab(
                          tasks: tasks,
                          onPauseTask: (comicId) {
                            unawaited(_pauseTask(comicId));
                          },
                          onResumeTask: (comicId) {
                            unawaited(_resumeTask(comicId));
                          },
                          onDeleteTask: (comicId) {
                            unawaited(_deleteTask(comicId));
                          },
                        ),
                        _DownloadsCompletedTab(
                          comics: comics,
                          selectionMode: _selectionMode,
                          selectedComicIds: _selectedComicIds,
                          onToggleSelection: _toggleSelection,
                          onOpenComic: (comic) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    DownloadedComicDetailPage(comic: comic),
                              ),
                            );
                          },
                          onDeleteComic: (comic) {
                            unawaited(_deleteSingleComic(comic));
                          },
                        ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}

class _DownloadsOngoingTab extends StatelessWidget {
  const _DownloadsOngoingTab({
    required this.tasks,
    required this.onPauseTask,
    required this.onResumeTask,
    required this.onDeleteTask,
  });

  final List<MangaDownloadTask> tasks;
  final ValueChanged<String> onPauseTask;
  final ValueChanged<String> onResumeTask;
  final ValueChanged<String> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(child: Text(l10n(context).downloadsEmptyOngoing));
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final task = tasks[index];
        final progress = task.progressValue;
        final statusText = switch (task.status) {
          MangaDownloadTaskStatus.queued =>
            l10n(context).downloadsStatusQueued,
          MangaDownloadTaskStatus.downloading =>
            l10n(context).downloadsStatusDownloading,
          MangaDownloadTaskStatus.paused => l10n(context).downloadsStatusPaused,
          MangaDownloadTaskStatus.failed => l10n(
            context,
          ).downloadsStatusFailed(task.errorMessage ?? ''),
        };
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (task.currentChapterTitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(task.currentChapterTitle!),
                ],
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: task.status == MangaDownloadTaskStatus.failed
                      ? null
                      : progress.clamp(0.0, 1.0),
                ),
                const SizedBox(height: 8),
                Text(
                  '$statusText  ${task.completedCount}/${task.totalCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (task.currentImageTotal > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n(context).downloadsCurrentProgress(
                      '${task.currentImageIndex}',
                      '${task.currentImageTotal}',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: task.status == MangaDownloadTaskStatus.downloading
                          ? () => onPauseTask(task.comicId)
                          : () => onResumeTask(task.comicId),
                      icon: Icon(
                        task.status == MangaDownloadTaskStatus.downloading
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                      ),
                      label: Text(
                        task.status == MangaDownloadTaskStatus.downloading
                            ? l10n(context).downloadsActionPause
                            : l10n(context).downloadsActionResume,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => onDeleteTask(task.comicId),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n(context).comicDetailDelete),
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
}

class _DownloadsCompletedTab extends StatelessWidget {
  const _DownloadsCompletedTab({
    required this.comics,
    required this.selectionMode,
    required this.selectedComicIds,
    required this.onToggleSelection,
    required this.onOpenComic,
    required this.onDeleteComic,
  });

  final List<DownloadedMangaComic> comics;
  final bool selectionMode;
  final Set<String> selectedComicIds;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final ValueChanged<DownloadedMangaComic> onDeleteComic;

  @override
  Widget build(BuildContext context) {
    if (comics.isEmpty) {
      return Center(child: Text(l10n(context).downloadsEmptyDownloaded));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: comics.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comic = comics[index];
        final selected = selectedComicIds.contains(comic.comicId);
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (selectionMode) {
                onToggleSelection(comic.comicId);
              } else {
                onOpenComic(comic);
              }
            },
            onLongPress: () => onToggleSelection(comic.comicId),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _DownloadedComicCover(
                    comic: comic,
                    heroTag: 'downloaded_cover_${comic.comicId}',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comic.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (comic.subTitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            comic.subTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          l10n(context).downloadsChapterCount(
                            '${comic.chapters.length}',
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!selectionMode)
                    IconButton(
                      tooltip: l10n(context).comicDetailDelete,
                      onPressed: () => onDeleteComic(comic),
                      icon: const Icon(Icons.delete_outline),
                    )
                  else
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: selected
                          ? Icon(
                              Icons.check_circle,
                              key: const ValueKey('selected'),
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const Icon(
                              Icons.circle_outlined,
                              key: ValueKey('unselected'),
                            ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DownloadedComicCover extends StatelessWidget {
  const _DownloadedComicCover({
    required this.comic,
    this.heroTag,
    this.onTap,
    this.width = 84,
    this.height = 118,
    this.borderRadius = 12,
  });

  final DownloadedMangaComic comic;
  final String? heroTag;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final localPath = comic.localCoverPath?.trim();
    final radius = BorderRadius.circular(borderRadius);
    Widget child;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        child = ClipRRect(
          borderRadius: radius,
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
          ),
        );
      } else {
        child = _buildFallback(context, radius);
      }
    } else if (comic.coverUrl.trim().isNotEmpty) {
      child = ClipRRect(
        borderRadius: radius,
        child: HazukiCachedImage(
          url: comic.coverUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    } else {
      child = _buildFallback(context, radius);
    }
    if (heroTag != null) {
      child = Hero(tag: heroTag!, child: child);
    }
    if (onTap != null) {
      child = InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: child,
      );
    }
    return child;
  }

  Widget _buildFallback(BuildContext context, BorderRadius radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}

class DownloadedComicDetailPage extends StatelessWidget {
  const DownloadedComicDetailPage({super.key, required this.comic});

  final DownloadedMangaComic comic;

  String get _coverHeroTag => 'downloaded_cover_${comic.comicId}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(
          comic.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DownloadedComicCover(
                comic: comic,
                heroTag: _coverHeroTag,
                width: 116,
                height: 162,
                borderRadius: 16,
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      opaque: false,
                      barrierColor: Colors.black54,
                      pageBuilder: (previewContext, animation, secondaryAnimation) {
                        return _DownloadedComicCoverPreviewPage(
                          comic: comic,
                          heroTag: _coverHeroTag,
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comic.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ) ??
                          const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                    ),
                    if (comic.subTitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(comic.subTitle),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      l10n(context).downloadsChapterCount(
                        '${comic.chapters.length}',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comic.description.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            _DownloadedComicExpandableDescription(
              text: comic.description.trim(),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            l10n(context).comicDetailChapters,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ...comic.chapters.map((chapter) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(chapter.title),
                subtitle: Text(
                  l10n(context).downloadsCurrentProgress(
                    '${chapter.imagePaths.length}',
                    '${chapter.imagePaths.length}',
                  ),
                ),
                trailing: const Icon(Icons.menu_book_outlined),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReaderPage(
                        title: comic.title,
                        chapterTitle: chapter.title,
                        comicId: comic.comicId,
                        epId: chapter.epId,
                        chapterIndex: chapter.index,
                        images: chapter.imagePaths,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DownloadedComicExpandableDescription extends StatefulWidget {
  const _DownloadedComicExpandableDescription({required this.text});

  final String text;

  @override
  State<_DownloadedComicExpandableDescription> createState() =>
      _DownloadedComicExpandableDescriptionState();
}

class _DownloadedComicExpandableDescriptionState
    extends State<_DownloadedComicExpandableDescription> {
  static const int _collapsedMaxLines = 5;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14, height: 1.5);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          maxLines: _collapsedMaxLines,
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: Text(
                widget.text,
                style: textStyle,
                maxLines: _expanded ? null : (isOverflowing ? _collapsedMaxLines : null),
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
            if (isOverflowing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded
                                ? l10n(context).comicDetailCollapse
                                : l10n(context).comicDetailExpand,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DownloadedComicCoverPreviewPage extends StatelessWidget {
  const _DownloadedComicCoverPreviewPage({
    required this.comic,
    required this.heroTag,
  });

  final DownloadedMangaComic comic;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final localPath = comic.localCoverPath?.trim();
    final networkUrl = comic.coverUrl.trim();
    final placeholderColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);

    Widget imageChild;
    if (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) {
      imageChild = Image.file(
        File(localPath),
        fit: BoxFit.contain,
      );
    } else if (networkUrl.isNotEmpty) {
      imageChild = HazukiCachedImage(
        url: networkUrl,
        fit: BoxFit.contain,
        loading: Container(
          width: 220,
          height: 300,
          color: placeholderColor,
        ),
        error: Container(
          width: 220,
          height: 300,
          color: placeholderColor,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
    } else {
      imageChild = Container(
        width: 220,
        height: 300,
        color: placeholderColor,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
              child: Hero(
                tag: heroTag,
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: imageChild,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
