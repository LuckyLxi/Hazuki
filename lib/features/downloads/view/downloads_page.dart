import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';
import '../downloads.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({
    super.key,
    required this.readerPageBuilder,
    this.downloadService,
    this.windowsComicDetailController,
  });

  final DownloadedComicReaderPageBuilder readerPageBuilder;
  final MangaDownloadService? downloadService;
  final WindowsComicDetailController? windowsComicDetailController;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage>
    with SingleTickerProviderStateMixin {
  late final Future<void> _initFuture;
  late final TabController _tabController;
  late final DownloadsPageController _controller;
  late final Listenable _pageListenable;

  bool get _selectionMode =>
      _controller.selectionModeForTab(_tabController.index);

  MangaDownloadService get _downloadService => _controller.downloadService;
  WindowsComicDetailController get _windowsController =>
      widget.windowsComicDetailController ??
      WindowsComicDetailController.instance;

  @override
  void initState() {
    super.initState();
    _controller = DownloadsPageController(
      downloadService: widget.downloadService ?? MangaDownloadService.instance,
    );
    _initFuture = _downloadService.ensureInitialized();
    _initFuture.then((_) {
      if (mounted) unawaited(_controller.runIntegrityCheck());
    });
    _tabController = TabController(length: 2, vsync: this);
    _pageListenable = Listenable.merge([
      _tabController,
      _controller,
      _downloadService,
    ]);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    _controller.handleTabChanged(
      tabIndex: _tabController.index,
      indexIsChanging: _tabController.indexIsChanging,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        return AnimatedBuilder(
          animation: _pageListenable,
          builder: (context, child) {
            final tasks = _downloadService.tasks;
            final comics = _downloadService.downloadedComics;
            return WindowsComicDetailHost(
              child: Scaffold(
                appBar: DownloadsPageAppBar(
                  tabController: _tabController,
                  selectionMode: _selectionMode,
                  selectedCount: _controller.selectedCount,
                ),
                body: !ready
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          DownloadsOngoingTab(
                            tasks: tasks,
                            onPauseTask: (comicId) {
                              unawaited(_controller.pauseTask(comicId));
                            },
                            onResumeTask: (comicId) {
                              unawaited(_controller.resumeTask(comicId));
                            },
                            onDeleteTask: (comicId) {
                              unawaited(
                                _controller.deleteTask(context, comicId),
                              );
                            },
                          ),
                          DownloadsCompletedTab(
                            comics: comics,
                            selectionMode: _selectionMode,
                            scanning: _controller.scanningDownloaded,
                            selectedCount: _controller.selectedCount,
                            selectedComicIds: _controller.selectedComicIds,
                            comicsWithIntegrityIssues:
                                _controller.comicsWithIntegrityIssues,
                            onToggleSelection: _controller.toggleSelection,
                            onToggleSelectionMode: () {
                              _controller.toggleSelectionMode(
                                _tabController.index,
                              );
                            },
                            onDeleteSelected: () {
                              unawaited(_controller.deleteSelected(context));
                            },
                            onScanDownloaded: () {
                              unawaited(
                                _controller.scanDownloadedComics(context),
                              );
                            },
                            onOpenComic: (comic) {
                              unawaited(() async {
                                if (useWindowsComicDetailPanel) {
                                  await _windowsController.closeAndWait();
                                  if (!context.mounted) {
                                    return;
                                  }
                                }
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => DownloadedComicDetailPage(
                                      comic: comic,
                                      readerPageBuilder:
                                          widget.readerPageBuilder,
                                    ),
                                  ),
                                );
                              }());
                            },
                            onDeleteComic: (comic) {
                              unawaited(
                                _controller.deleteSingleComic(context, comic),
                              );
                            },
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
