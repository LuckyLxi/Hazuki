import 'package:flutter/widgets.dart';
import 'package:hazuki/l10n/l10n.dart';
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
    required this.removedComicCount,
    required this.removedGroupIds,
  });

  final int comicCount;
  final int removedComicCount;
  final Set<String> removedGroupIds;
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
  int comicCountForGroup(String groupId) =>
      _downloadGroupsService.comicKeysForGroup(groupId).length;
  Set<String> groupIdsForComic(DownloadedMangaComic comic) =>
      _downloadGroupsService.groupIdsForComic(comic.storageKey);
  Set<String> get commonGroupIdsForSelectedComics {
    Set<String>? common;
    for (final key in _selectedComicIds) {
      final groups = _downloadGroupsService.groupIdsForComic(key);
      common = common == null ? groups : common.intersection(groups);
    }
    return common ?? const {};
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
    );
  }

  void selectGroup(String groupId) {
    if (_selectedGroupId == groupId) return;
    _selectedGroupId = groupId;
    _clearSelection(notify: false);
    _notify();
  }

  Future<DownloadGroup> createGroup(String name) =>
      _downloadGroupsService.createGroup(name);

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
    Set<String> groupIds,
  ) async {
    final keys = Set<String>.of(_selectedComicIds);
    final removedGroupIds = <String>{};
    var removedComicCount = 0;
    for (final key in keys) {
      final removed = _downloadGroupsService
          .groupIdsForComic(key)
          .difference(groupIds);
      if (removed.isNotEmpty) {
        removedComicCount++;
        removedGroupIds.addAll(removed);
      }
    }
    await _downloadGroupsService.moveComicsToGroups(keys, groupIds);
    _clearSelection(notify: true);
    return UpdateSelectedComicGroupsResult(
      comicCount: keys.length,
      removedComicCount: removedComicCount,
      removedGroupIds: removedGroupIds,
    );
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
    for (final key in _selectedComicIds) {
      await _downloadGroupsService.removeComic(key);
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
    await _downloadGroupsService.removeComic(comic.storageKey);
    await _downloadService.deleteDownloadedComics([comic.storageKey]);
  }

  Future<void> pauseTask(String comicId) async {
    await _downloadService.pauseTask(comicId);
  }

  Future<void> resumeTask(String comicId) async {
    await _downloadService.resumeTask(comicId);
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
