import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';
import 'package:hazuki/widgets/widgets.dart';
import '../downloads.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import '../support/downloads_group_actions.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({
    super.key,
    required this.readerPageBuilder,
    required this.downloadService,
    required this.downloadGroupsService,
    this.windowsComicDetailController,
  });

  final DownloadedComicReaderPageBuilder readerPageBuilder;
  final MangaDownloadService downloadService;
  final DownloadGroupsService downloadGroupsService;
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
      downloadService: widget.downloadService,
      downloadGroupsService: widget.downloadGroupsService,
    );
    _initFuture = _controller.initialize();
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

  String _groupNames(BuildContext context, Iterable<String> groupIds) {
    final names = <String>[];
    for (final id in groupIds) {
      DownloadGroup? group;
      for (final candidate in _controller.groups) {
        if (candidate.id == id) {
          group = candidate;
          break;
        }
      }
      if (group == null) continue;
      names.add(
        group.isDefault ? l10n(context).downloadsDefaultGroup : group.name,
      );
    }
    return names.join(', ');
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
            final comics = _controller.filteredDownloadedComics;
            return PopScope(
              canPop: !_selectionMode,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) {
                  _controller.exitSelectionMode(_tabController.index);
                }
              },
              child: WindowsComicDetailHost(
                child: Scaffold(
                  appBar: DownloadsPageAppBar(
                    tabController: _tabController,
                    selectionMode: _selectionMode,
                    selectedCount: _controller.selectedCount,
                    // 当前组有漫画且均被选中则认为已全选
                    allSelected:
                        comics.isNotEmpty &&
                        _controller.selectedCount == comics.length,
                    onToggleSelectionMode: () {
                      _controller.toggleSelectionMode(_tabController.index);
                    },
                    onSelectAll: () {
                      // 切换全选：已全选则取消全选，否则全选当前组内所有漫画
                      _controller.toggleSelectAll(
                        comics.map((c) => c.storageKey),
                      );
                    },
                    onPauseAll: () {
                      // 一键暂停所有下载任务
                      unawaited(_pauseAllTasks(tasks));
                    },
                    onResumeAll: () {
                      // 一键开始所有暂停或失败的下载任务
                      unawaited(_resumeAllTasks(tasks));
                    },
                  ),
                  body: !ready
                      ? const Center(child: CircularProgressIndicator())
                      : ScrollConfiguration(
                          key: const ValueKey<String>(
                            'downloads_tab_scroll_configuration',
                          ),
                          behavior: ScrollConfiguration.of(
                            context,
                          ).copyWith(overscroll: false),
                          child: TabBarView(
                            controller: _tabController,
                            physics: const ClampingScrollPhysics(),
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
                                model: DownloadsCompletedTabModel(
                                  comics: comics,
                                  active: _tabController.index == 1,
                                  selectionMode: _selectionMode,
                                  scanning: _controller.scanningDownloaded,
                                  selectedCount: _controller.selectedCount,
                                  selectedComicIds:
                                      _controller.selectedComicIds,
                                  comicsWithIntegrityIssues:
                                      _controller.comicsWithIntegrityIssues,
                                  groups: _controller.groups,
                                  selectedGroupId: _controller.selectedGroupId,
                                  selectedGroupName:
                                      _controller.selectedGroup.isDefault
                                      ? l10n(context).downloadsDefaultGroup
                                      : _controller.selectedGroup.name,
                                  selectedGroupComicCount: _controller
                                      .comicCountForGroup(
                                        _controller.selectedGroupId,
                                      ),
                                  groupComicCounts: {
                                    for (final group in _controller.groups)
                                      group.id: _controller.comicCountForGroup(
                                        group.id,
                                      ),
                                  },
                                ),
                                actions: DownloadsCompletedTabActions(
                                  onToggleSelection:
                                      _controller.toggleSelection,
                                  onDeleteSelected: () {
                                    unawaited(
                                      _controller.deleteSelected(context),
                                    );
                                  },
                                  onBatchGroup: () {
                                    unawaited(() async {
                                      final selection =
                                          await showDownloadsBulkGroupDialog(
                                            context: context,
                                            groups: _controller.groups,
                                            selectedComics: _controller
                                                .selectedDownloadedComics,
                                            initialComicKeysByGroup: _controller
                                                .selectedComicKeysByGroup,
                                            currentGroupName:
                                                _controller
                                                    .selectedGroup
                                                    .isDefault
                                                ? l10n(
                                                    context,
                                                  ).downloadsDefaultGroup
                                                : _controller
                                                      .selectedGroup
                                                      .name,
                                          );
                                      if (selection == null ||
                                          !context.mounted) {
                                        return;
                                      }
                                      final comicCount =
                                          selection.action ==
                                              DownloadsBulkGroupAction
                                                  .removeFromCurrentGroup
                                          ? await _controller
                                                .removeSelectedComicsFromCurrentGroup()
                                          : (await _controller
                                                    .updateSelectedComicsGroups(
                                                      selection
                                                          .comicKeysByGroup,
                                                    ))
                                                .comicCount;
                                      if (!context.mounted) return;
                                      unawaited(
                                        showHazukiPrompt(
                                          context,
                                          selection.action ==
                                                  DownloadsBulkGroupAction
                                                      .removeFromCurrentGroup
                                              ? l10n(
                                                  context,
                                                ).downloadsBatchRemovedFromGroup(
                                                  comicCount,
                                                  _controller
                                                          .selectedGroup
                                                          .isDefault
                                                      ? l10n(
                                                          context,
                                                        ).downloadsDefaultGroup
                                                      : _controller
                                                            .selectedGroup
                                                            .name,
                                                )
                                              : l10n(
                                                  context,
                                                ).downloadsBatchGroupsUpdated(
                                                  comicCount,
                                                ),
                                        ),
                                      );
                                    }());
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
                                          builder: (_) =>
                                              DownloadedComicDetailPage(
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
                                      _controller.deleteSingleComic(
                                        context,
                                        comic,
                                      ),
                                    );
                                  },
                                  onSelectGroup: _controller.selectGroup,
                                  onCreateGroup: _controller.createGroup,
                                  onRenameGroup: _controller.renameGroup,
                                  onReorderGroups: _controller.reorderGroups,
                                  onDeleteGroup: _controller.deleteGroup,
                                  onShowComicMenu:
                                      (
                                        comic,
                                        globalPosition,
                                        itemContext,
                                      ) async {
                                        final action =
                                            await showDownloadsComicMenu(
                                              context: context,
                                              itemContext: itemContext,
                                              globalPosition: globalPosition,
                                            );
                                        if (!context.mounted ||
                                            action == null) {
                                          return;
                                        }
                                        if (action ==
                                            DownloadsComicMenuAction.delete) {
                                          await _controller.deleteSingleComic(
                                            context,
                                            comic,
                                          );
                                          return;
                                        }
                                        if (action ==
                                            DownloadsComicMenuAction
                                                .removeFromCurrentGroup) {
                                          final selectedGroup =
                                              _controller.selectedGroup;
                                          final removed = await _controller
                                              .removeComicFromCurrentGroup(
                                                comic,
                                              );
                                          if (!context.mounted) {
                                            return;
                                          }
                                          if (!removed) {
                                            unawaited(
                                              showHazukiPrompt(
                                                context,
                                                l10n(
                                                  context,
                                                ).downloadsCannotRemoveOnlyDefaultGroup,
                                              ),
                                            );
                                            return;
                                          }
                                          unawaited(
                                            showHazukiPrompt(
                                              context,
                                              l10n(
                                                context,
                                              ).downloadsComicRemovedFromGroup(
                                                selectedGroup.isDefault
                                                    ? l10n(
                                                        context,
                                                      ).downloadsDefaultGroup
                                                    : selectedGroup.name,
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        final selectedGroupIds =
                                            await showDownloadGroupPicker(
                                              context: context,
                                              groups: _controller.groups,
                                              initiallySelectedGroupIds:
                                                  _controller.groupIdsForComic(
                                                    comic,
                                                  ),
                                            );
                                        if (selectedGroupIds == null) return;
                                        final updated = await _controller
                                            .updateComicGroups(
                                              comic,
                                              selectedGroupIds,
                                            );
                                        if (!context.mounted) return;
                                        final message = !updated.changed
                                            ? l10n(
                                                context,
                                              ).downloadsGroupAlreadyContainsComic
                                            : updated.removedGroupIds.length ==
                                                  1
                                            ? l10n(
                                                context,
                                              ).downloadsComicRemovedFromGroup(
                                                _groupNames(
                                                  context,
                                                  updated.removedGroupIds,
                                                ),
                                              )
                                            : updated.removedGroupIds.isNotEmpty
                                            ? l10n(
                                                context,
                                              ).downloadsComicRemovedFromGroups(
                                                updated.removedGroupIds.length,
                                              )
                                            : l10n(
                                                context,
                                              ).downloadsAddedToGroups(
                                                _groupNames(
                                                  context,
                                                  updated.addedGroupIds,
                                                ),
                                              );
                                        unawaited(
                                          showHazukiPrompt(context, message),
                                        );
                                      },
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pauseAllTasks(List<MangaDownloadTask> tasks) async {
    final strings = l10n(context);
    if (tasks.isEmpty) {
      await showHazukiPrompt(context, strings.downloadsNoTasks);
      return;
    }
    await _controller.pauseAllTasks();
    if (!mounted) return;
    await showHazukiPrompt(context, strings.downloadsAllTasksPaused);
  }

  Future<void> _resumeAllTasks(List<MangaDownloadTask> tasks) async {
    final strings = l10n(context);
    if (tasks.isEmpty) {
      await showHazukiPrompt(context, strings.downloadsNoTasks);
      return;
    }
    await _controller.resumeAllTasks();
    if (!mounted) return;
    await showHazukiPrompt(context, strings.downloadsAllTasksResumed);
  }
}
