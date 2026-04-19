import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app.dart';
import '../l10n/app_localizations.dart';
import '../models/hazuki_models.dart';
import '../services/hazuki_source_service.dart';
import '../services/local_favorites_service.dart';
import '../widgets/widgets.dart';
import '../widgets/windows_comic_detail_host.dart';
import 'package:hazuki/features/comic_detail/comic_detail.dart';

part 'history/history_actions.dart';
part 'history/history_favorites_actions.dart';
part 'history/history_widgets.dart';

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
      } catch (_) {}
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
    final jsonList = history
        .map(
          (e) => {
            'id': e.id,
            'title': e.title,
            'cover': e.cover,
            'subTitle': e.subTitle,
          },
        )
        .toList();
    await prefs.setString('hazuki_read_history', jsonEncode(jsonList));
  }

  void _updateHistoryState(VoidCallback updater) {
    if (!mounted) {
      return;
    }
    setState(updater);
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
