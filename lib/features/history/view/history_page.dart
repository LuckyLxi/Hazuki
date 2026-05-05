import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/history_actions.dart';
import '../support/history_favorite_support.dart';
import '../support/history_menu_support.dart';
import 'history_comic_list_item.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ScrollController _scrollController = ScrollController();

  List<ExploreComic> _history = [];
  bool _loading = true;
  bool _selectionMode = false;
  bool _showBackToTop = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final nextShowBackToTop = position.pixels > 520;
    if (nextShowBackToTop != _showBackToTop && mounted) {
      setState(() {
        _showBackToTop = nextShowBackToTop;
      });
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('hazuki_read_history');
    if (jsonStr != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        final history = jsonList
            .map(
              (e) => ExploreComic(
                id: e['id'] as String? ?? '',
                title: e['title'] as String? ?? '',
                cover: e['cover'] as String? ?? '',
                subTitle: e['subTitle'] as String? ?? '',
                sourceKey: e['sourceKey'] as String? ?? '',
              ),
            )
            .toList();
        if (mounted) {
          setState(() {
            _history = history;
            _loading = false;
          });
        }
        return;
      } catch (e, st) {
        debugPrint('history: failed to parse history JSON: $e\n$st');
      }
    }
    if (mounted) {
      setState(() {
        _history = [];
        _loading = false;
      });
    }
  }

  Future<void> _saveHistory(List<ExploreComic> history) async {
    final prefs = await SharedPreferences.getInstance();
    // 读取原始JSON以保留timestamp等额外字段，避免云同步合并时丢失时序信息
    final existingStr = prefs.getString('hazuki_read_history');
    final existingById = <String, Map<String, dynamic>>{};
    if (existingStr != null) {
      try {
        final List<dynamic> existing = jsonDecode(existingStr);
        for (final e in existing) {
          final id = (e['id'] as String?) ?? '';
          final sourceKey = (e['sourceKey'] as String?) ?? '';
          if (id.isNotEmpty) {
            existingById[SourceScopedComicId(
              sourceKey: sourceKey,
              comicId: id,
            ).storageKey] = Map<String, dynamic>.from(
              e as Map,
            );
          }
        }
      } catch (_) {}
    }
    final jsonList = history.map((e) {
      final base = existingById[e.scopedId.storageKey] ?? <String, dynamic>{};
      return <String, dynamic>{
        ...base,
        'id': e.id,
        'sourceKey': e.sourceKey,
        'title': e.title,
        'cover': e.cover,
        'subTitle': e.subTitle,
      };
    }).toList();
    await prefs.setString('hazuki_read_history', jsonEncode(jsonList));
  }

  void _updateHistoryState(VoidCallback updater) {
    if (!mounted) {
      return;
    }
    setState(updater);
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) {
      return;
    }

    final confirm = await showDeleteSelectedHistoryDialog(
      context,
      selectedCount: _selectedIds.length,
    );
    if (confirm != true) {
      return;
    }

    final newHistory = _history
        .where((e) => !_selectedIds.contains(e.scopedId.storageKey))
        .toList();
    await _saveHistory(newHistory);
    _updateHistoryState(() {
      _history = newHistory;
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showClearHistoryDialog(context);
    if (confirm != true) {
      return;
    }

    await _saveHistory([]);
    _updateHistoryState(() {
      _history = [];
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _handleCopyComicId(ExploreComic comic) async {
    await copyHistoryComicId(context, comic.id);
  }

  Future<void> _handleDeleteHistoryItem(ExploreComic comic) async {
    final newHistory = _history
        .where((e) => e.scopedId.storageKey != comic.scopedId.storageKey)
        .toList();
    await _saveHistory(newHistory);
    _updateHistoryState(() {
      _history = newHistory;
    });
  }

  Future<void> _handleToggleFavoriteFromHistory(ExploreComic comic) async {
    await toggleFavoriteFromHistory(context, comic);
  }

  Future<void> _showComicMenu(
    ExploreComic comic,
    Offset globalPosition,
    BuildContext itemContext,
  ) async {
    final action = await showHistoryComicMenu(
      context: context,
      itemContext: itemContext,
      globalPosition: globalPosition,
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case HistoryComicMenuAction.copy:
        await _handleCopyComicId(comic);
        break;
      case HistoryComicMenuAction.favorite:
        await _handleToggleFavoriteFromHistory(comic);
        break;
      case HistoryComicMenuAction.delete:
        await _handleDeleteHistoryItem(comic);
        break;
    }
  }

  void _toggleSelection(String storageKey, {bool? selected}) {
    _updateHistoryState(() {
      if (selected ?? !_selectedIds.contains(storageKey)) {
        _selectedIds.add(storageKey);
      } else {
        _selectedIds.remove(storageKey);
      }
    });
  }

  Widget _buildItem(ExploreComic comic, int index) {
    final heroTag = widget.comicCoverHeroTagBuilder(comic, salt: 'history');
    return HistoryComicListItem(
      key: ValueKey(comic.scopedId.storageKey),
      comic: comic,
      index: index,
      heroTag: heroTag,
      selectionMode: _selectionMode,
      selected: _selectedIds.contains(comic.scopedId.storageKey),
      onShowMenu: (globalPosition, itemContext) =>
          _showComicMenu(comic, globalPosition, itemContext),
      onToggleSelection: (selected) =>
          _toggleSelection(comic.scopedId.storageKey, selected: selected),
      onTap: () async {
        if (_selectionMode) {
          _toggleSelection(comic.scopedId.storageKey);
          return;
        }
        await openComicDetail(
          context,
          comic: comic,
          heroTag: heroTag,
          pageBuilder: widget.comicDetailPageBuilder,
        );
        if (!mounted) {
          return;
        }
        await _loadHistory();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final bodyContent = _loading
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HazukiSandyLoadingIndicator(size: 136),
                const SizedBox(height: 10),
                Text(strings.commonLoading),
              ],
            ),
          )
        : _history.isEmpty
        ? Center(child: Text(strings.historyEmpty))
        : ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.all(16),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              return _buildItem(_history[index], index);
            },
          );

    return WindowsComicDetailHost(
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(strings.historyTitle),
          actions: [
            if (_history.isNotEmpty)
              IconButton(
                tooltip: _selectionMode
                    ? strings.historySelectionCancelTooltip
                    : strings.historySelectionEnterTooltip,
                icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
                onPressed: () {
                  _updateHistoryState(() {
                    _selectionMode = !_selectionMode;
                    _selectedIds.clear();
                  });
                },
              ),
            if (_history.isNotEmpty)
              IconButton(
                tooltip: _selectionMode
                    ? strings.historyDeleteSelectedTooltip
                    : strings.historyClearAllTooltip,
                icon: const Icon(Icons.delete_outline),
                onPressed: _selectionMode ? _deleteSelected : _clearAll,
              ),
          ],
        ),
        body: Stack(
          children: [
            bodyContent,
            Positioned(
              right: 16,
              bottom: 16,
              child: AnimatedSlide(
                offset: _showBackToTop ? Offset.zero : const Offset(0, 0.24),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedScale(
                  scale: _showBackToTop ? 1 : 0.86,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _showBackToTop ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !_showBackToTop,
                      child: FloatingActionButton(
                        heroTag: 'history_back_to_top',
                        onPressed: _scrollToTop,
                        child: const Icon(Icons.vertical_align_top_rounded),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
