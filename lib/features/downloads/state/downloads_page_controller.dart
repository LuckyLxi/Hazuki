import 'package:flutter/widgets.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/download_groups_service.dart';
import '../support/downloads_actions.dart';

class UpdateComicGroupsResult {
  const UpdateComicGroupsResult({
    required this.changed,
    this.addedGroupIds = const {},
    this.removedGroupIds = const {},
  });

  final bool changed;
  final Set<String> addedGroupIds;
  final Set<String> removedGroupIds;
}

class UpdateSelectedComicGroupsResult {
  const UpdateSelectedComicGroupsResult({
    required this.comicCount,
    required this.changedGroupCount,
  });

  final int comicCount;
  final int changedGroupCount;
}

class DownloadsPageController extends ChangeNotifier {
  DownloadsPageController({
    required MangaDownloadService downloadService,
    required DownloadGroupsService downloadGroupsService,
  }) : _downloadService = downloadService,
       _downloadGroupsService = downloadGroupsService {
    _downloadService.addListener(_handleDownloadsChanged);
    _downloadGroupsService.addListener(_notify);
  }

  final MangaDownloadService _downloadService;
  final DownloadGroupsService _downloadGroupsService;
  String _selectedGroupId = DownloadGroupsService.defaultGroupId;
  bool _reconcilingGroups = false;

  MangaDownloadService get downloadService => _downloadService;
  DownloadGroupsService get downloadGroupsService => _downloadGroupsService;
  List<DownloadGroup> get groups => _downloadGroupsService.groups;
  String get selectedGroupId => _selectedGroupId;
  DownloadGroup get selectedGroup => groups.firstWhere(
    (group) => group.id == _selectedGroupId,
    orElse: () => const DownloadGroup(
      id: DownloadGroupsService.defaultGroupId,
      name: DownloadGroupsService.defaultGroupName,
      createdAtMs: 0,
    ),
  );
  int comicCountForGroup(String groupId) {
    final downloadedKeys = _downloadService.downloadedComics
        .map((comic) => comic.storageKey)
        .toSet();
    return _downloadGroupsService
        .comicKeysForGroup(groupId)
        .where(downloadedKeys.contains)
        .length;
  }

  Set<String> groupIdsForComic(DownloadedMangaComic comic) =>
      _downloadGroupsService.groupIdsForComic(comic.storageKey);
  Map<String, Set<String>> get selectedComicKeysByGroup {
    return {
      for (final group in groups)
        group.id: {
          for (final key in _selectedComicIds)
            if (_downloadGroupsService.groupContainsComic(group.id, key)) key,
        },
    };
  }

  List<DownloadedMangaComic> get selectedDownloadedComics {
    return _downloadService.downloadedComics
        .where((comic) => _selectedComicIds.contains(comic.storageKey))
        .toList(growable: false);
  }

  List<DownloadedMangaComic> get filteredDownloadedComics {
    final keys = _downloadGroupsService.comicKeysForGroup(_selectedGroupId);
    return _downloadService.downloadedComics
        .where((comic) => keys.contains(comic.storageKey))
        .toList(growable: false);
  }

  final Set<String> _selectedComicIds = <String>{};
  bool _selectionEnabled = false;
  bool _scanningDownloaded = false;
  bool _checkingIntegrity = false;
  bool _disposed = false;
  Set<String> _comicsWithIntegrityIssues = const {};

  Set<String> get selectedComicIds =>
      Set<String>.unmodifiable(_selectedComicIds);
  int get selectedCount => _selectedComicIds.length;
  bool get scanningDownloaded => _scanningDownloaded;
  Set<String> get comicsWithIntegrityIssues =>
      Set<String>.unmodifiable(_comicsWithIntegrityIssues);

  Future<void> initialize() async {
    await _downloadService.ensureInitialized();
    await _downloadGroupsService.initialize(
      _downloadService.downloadedComics.map((comic) => comic.storageKey),
      migratedComicKeys: _legacyComicKeyMigrations,
    );
  }

  Map<String, String> get _legacyComicKeyMigrations => {
    for (final comic in _downloadService.downloadedComics)
      if (isHazukiJmSourceKey(comic.sourceKey)) comic.comicId: comic.storageKey,
  };

  void selectGroup(String groupId) {
    if (_selectedGroupId == groupId) return;
    _selectedGroupId = groupId;
    _clearSelection(notify: false);
    _notify();
  }

  Future<DownloadGroup> createGroup(String name) =>
      _downloadGroupsService.createGroup(name);

  Future<DownloadGroup> renameGroup(String groupId, String name) =>
      _downloadGroupsService.renameGroup(groupId, name);

  Future<void> reorderGroups(List<String> orderedGroupIds) =>
      _downloadGroupsService.reorderGroups(orderedGroupIds);

  Future<void> deleteGroup(String groupId) async {
    await _downloadGroupsService.deleteGroup(groupId);
    if (_selectedGroupId == groupId) {
      _selectedGroupId = DownloadGroupsService.defaultGroupId;
    }
    _notify();
  }

  Future<UpdateComicGroupsResult> updateComicGroups(
    DownloadedMangaComic comic,
    Set<String> groupIds,
  ) async {
    final current = _downloadGroupsService.groupIdsForComic(comic.storageKey);
    final added = groupIds.difference(current);
    final removed = current.difference(groupIds);
    if (added.isEmpty && removed.isEmpty) {
      return const UpdateComicGroupsResult(changed: false);
    }
    await _downloadGroupsService.moveComicToGroups(comic.storageKey, groupIds);
    return UpdateComicGroupsResult(
      changed: true,
      addedGroupIds: added,
      removedGroupIds: removed,
    );
  }

  Future<UpdateSelectedComicGroupsResult> updateSelectedComicsGroups(
    Map<String, Set<String>> desiredComicKeysByGroup,
  ) async {
    final keys = Set<String>.of(_selectedComicIds);
    var changedGroupCount = 0;
    for (final entry in desiredComicKeysByGroup.entries) {
      final current = {
        for (final key in keys)
          if (_downloadGroupsService.groupContainsComic(entry.key, key)) key,
      };
      final desired = entry.value.intersection(keys);
      final added = desired.difference(current);
      final removed = current.difference(desired);
      if (added.isEmpty && removed.isEmpty) continue;
      changedGroupCount++;
      if (added.isNotEmpty) {
        await _downloadGroupsService.addComicsToGroups(added, [entry.key]);
      }
      if (removed.isNotEmpty) {
        await _downloadGroupsService.removeComicsFromGroup(removed, entry.key);
      }
    }
    _clearSelection(notify: true);
    return UpdateSelectedComicGroupsResult(
      comicCount: keys.length,
      changedGroupCount: changedGroupCount,
    );
  }

  Future<int> removeSelectedComicsFromCurrentGroup() async {
    final keys = Set<String>.of(_selectedComicIds);
    final removableKeys =
        _selectedGroupId == DownloadGroupsService.defaultGroupId
        ? {
            for (final key in keys)
              if (_downloadGroupsService.groupIdsForComic(key).length > 1) key,
          }
        : keys;
    await _downloadGroupsService.removeComicsFromGroup(
      removableKeys,
      _selectedGroupId,
    );
    _clearSelection(notify: true);
    return removableKeys.length;
  }

  Future<bool> removeComicFromCurrentGroup(DownloadedMangaComic comic) async {
    final groupId = _selectedGroupId;
    if (groupId == DownloadGroupsService.defaultGroupId &&
        _downloadGroupsService.groupIdsForComic(comic.storageKey).length <= 1) {
      return false;
    }
    await _downloadGroupsService.removeComicsFromGroup([
      comic.storageKey,
    ], groupId);
    return true;
  }

  bool selectionModeForTab(int tabIndex) =>
      tabIndex == 1 && (_selectionEnabled || _selectedComicIds.isNotEmpty);

  void handleTabChanged({
    required int tabIndex,
    required bool indexIsChanging,
  }) {
    if (indexIsChanging || tabIndex == 1) {
      return;
    }
    _clearSelection(notify: true);
  }

  void toggleSelection(String comicId) {
    if (_selectedComicIds.contains(comicId)) {
      _selectedComicIds.remove(comicId);
    } else {
      _selectedComicIds.add(comicId);
    }
    _notify();
  }

  /// 切换全选状态：当前已全选则取消全选，否则全选指定范围内的漫画
  void toggleSelectAll(Iterable<String> comicKeys) {
    final keys = comicKeys.toList();
    // 判断是否已全选：所有 key 都在已选集合里
    final isAllSelected =
        keys.isNotEmpty && keys.every(_selectedComicIds.contains);
    if (isAllSelected) {
      // 已全选 → 取消全选
      _selectedComicIds.removeAll(keys);
    } else {
      // 未全选 → 全选
      _selectedComicIds.addAll(keys);
    }
    _notify();
  }

  void toggleSelectionMode(int tabIndex) {
    if (selectionModeForTab(tabIndex)) {
      exitSelectionMode(tabIndex);
      return;
    }
    _selectionEnabled = true;
    _notify();
  }

  bool exitSelectionMode(int tabIndex) {
    if (!selectionModeForTab(tabIndex)) {
      return false;
    }
    _clearSelection(notify: true);
    return true;
  }

  Future<void> deleteSelected(BuildContext context) async {
    if (_selectedComicIds.isEmpty) {
      return;
    }
    final strings = l10n(context);
    final confirmed = await showDownloadsDeleteDialog(
      context,
      title: strings.downloadsDeleteSelectedTitle,
      content: strings.downloadsDeleteSelectedContent('$selectedCount'),
    );
    if (confirmed != true) {
      return;
    }
    await _downloadService.deleteDownloadedComics(_selectedComicIds);
    _clearSelection(notify: true);
  }

  Future<void> deleteSingleComic(
    BuildContext context,
    DownloadedMangaComic comic,
  ) async {
    final strings = l10n(context);
    final confirmed = await showDownloadsDeleteDialog(
      context,
      title: strings.downloadsDeleteSelectedTitle,
      content: strings.downloadsDeleteSelectedContent('1'),
    );
    if (confirmed != true) {
      return;
    }
    await _downloadService.deleteDownloadedComics([comic.storageKey]);
  }

  Future<void> pauseTask(String comicId) async {
    await _downloadService.pauseTask(comicId);
  }

  Future<void> resumeTask(String comicId) async {
    await _downloadService.resumeTask(comicId);
  }

  /// 暂停所有下载任务
  Future<void> pauseAllTasks() async {
    await _downloadService.pauseAllTasks();
  }

  /// 恢复所有暂停或失败的下载任务
  Future<void> resumeAllTasks() async {
    await _downloadService.resumeAllTasks();
  }

  Future<void> deleteTask(BuildContext context, String comicId) async {
    final strings = l10n(context);
    final confirmed = await showDownloadsDeleteDialog(
      context,
      title: strings.comicDetailDelete,
      content: strings.downloadsDeleteSelectedContent('1'),
    );
    if (confirmed != true) {
      return;
    }
    await _downloadService.deleteTask(comicId);
  }

  Future<void> runIntegrityCheck() async {
    if (_checkingIntegrity) return;
    _checkingIntegrity = true;
    try {
      _comicsWithIntegrityIssues = await _downloadService
          .checkDownloadedIntegrity();
      _notify();
    } finally {
      _checkingIntegrity = false;
    }
  }

  Future<void> scanDownloadedComics(BuildContext context) async {
    if (_scanningDownloaded) {
      return;
    }
    _scanningDownloaded = true;
    _notify();
    try {
      final result = await _downloadService.scanDownloadedComics();
      if (!context.mounted) {
        return;
      }
      await showDownloadsScanResultPrompt(context, result);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      await showDownloadsScanErrorPrompt(context, error);
    } finally {
      _scanningDownloaded = false;
      _notify();
    }
  }

  void _clearSelection({required bool notify}) {
    final hadSelection = _selectionEnabled || _selectedComicIds.isNotEmpty;
    _selectionEnabled = false;
    _selectedComicIds.clear();
    if (notify && hadSelection) {
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _handleDownloadsChanged() {
    if (!_reconcilingGroups) {
      _reconcilingGroups = true;
      _downloadGroupsService
          .reconcileDownloadedComics(
            _downloadService.downloadedComics.map((comic) => comic.storageKey),
            migratedComicKeys: _legacyComicKeyMigrations,
          )
          .whenComplete(() => _reconcilingGroups = false);
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _downloadService.removeListener(_handleDownloadsChanged);
    _downloadGroupsService.removeListener(_notify);
    super.dispose();
  }
}
