import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import '../../services/manga_download_service.dart';
import 'downloads_actions.dart';

class DownloadsPageController extends ChangeNotifier {
  DownloadsPageController({MangaDownloadService? downloadService})
    : _downloadService = downloadService ?? MangaDownloadService.instance;

  final MangaDownloadService _downloadService;

  final Set<String> _selectedComicIds = <String>{};
  bool _selectionEnabled = false;
  bool _scanningDownloaded = false;
  bool _disposed = false;

  Set<String> get selectedComicIds => Set<String>.unmodifiable(_selectedComicIds);
  int get selectedCount => _selectedComicIds.length;
  bool get scanningDownloaded => _scanningDownloaded;

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
      _clearSelection(notify: true);
      return;
    }
    _selectionEnabled = true;
    _notify();
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
    await _downloadService.deleteDownloadedComics([comic.comicId]);
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
