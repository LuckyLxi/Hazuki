import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';

/// 首页“继续阅读”中的一条记录：历史漫画及其本地阅读进度。
@immutable
class DiscoverContinueReadingEntry {
  const DiscoverContinueReadingEntry({required this.comic, this.progress});

  final ExploreComic comic;

  /// 本地阅读进度；从未进入阅读器时为空。
  final ({String chapterTitle, int pageIndex})? progress;
}

/// 读取当前源最近阅读的几部漫画，供 Windows 发现页首屏展示。
class DiscoverContinueReadingController extends ChangeNotifier {
  DiscoverContinueReadingController({
    required ReadHistoryService readHistoryService,
    required ReadingProgressService readingProgressService,
    required String? Function() activeSourceKey,
    Listenable? sourceChanges,
    this.maxEntries = 3,
  }) : _readHistoryService = readHistoryService,
       _readingProgressService = readingProgressService,
       _activeSourceKey = activeSourceKey,
       _sourceChanges = sourceChanges {
    _lastSourceKey = _activeSourceKey() ?? '';
    _readHistoryService.addListener(_scheduleReload);
    _sourceChanges?.addListener(_handleSourceChanged);
    _progressSubscription = _readingProgressService.changes.listen(
      (_) => _scheduleReload(),
    );
  }

  final ReadHistoryService _readHistoryService;
  final ReadingProgressService _readingProgressService;
  final String? Function() _activeSourceKey;
  final Listenable? _sourceChanges;
  final int maxEntries;

  StreamSubscription<void>? _progressSubscription;
  List<DiscoverContinueReadingEntry> _entries = const [];
  String _lastSourceKey = '';
  int _requestVersion = 0;
  bool _reloadScheduled = false;
  bool _disposed = false;

  List<DiscoverContinueReadingEntry> get entries => _entries;

  Future<void> load() async {
    final version = ++_requestVersion;
    final sourceKey = _activeSourceKey() ?? '';
    if (sourceKey.isEmpty) {
      _apply(version, const []);
      return;
    }
    try {
      final history = await _readHistoryService.loadHistory(
        sourceKey: sourceKey,
      );
      final entries = <DiscoverContinueReadingEntry>[];
      for (final comic in history.take(maxEntries)) {
        final raw = await _readingProgressService.load(
          comicId: comic.id,
          sourceKey: comic.sourceKey.isEmpty ? sourceKey : comic.sourceKey,
        );
        entries.add(
          DiscoverContinueReadingEntry(comic: comic, progress: _parse(raw)),
        );
      }
      _apply(version, List.unmodifiable(entries));
    } catch (_) {
      // 历史读取失败时不影响发现页其余内容，保留上一次结果。
    }
  }

  ({String chapterTitle, int pageIndex})? _parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final title = (raw['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return null;
    final pageIndex = (raw['pageIndex'] as num?)?.toInt() ?? 0;
    return (chapterTitle: title, pageIndex: pageIndex < 0 ? 0 : pageIndex);
  }

  void _apply(int version, List<DiscoverContinueReadingEntry> entries) {
    if (_disposed || version != _requestVersion) return;
    _entries = entries;
    notifyListeners();
  }

  void _handleSourceChanged() {
    final sourceKey = _activeSourceKey() ?? '';
    if (sourceKey == _lastSourceKey) return;
    _lastSourceKey = sourceKey;
    _scheduleReload();
  }

  // 历史与进度常在同一次阅读中连续写入，合并到一次微任务里重新读取。
  void _scheduleReload() {
    if (_disposed || _reloadScheduled) return;
    _reloadScheduled = true;
    scheduleMicrotask(() {
      _reloadScheduled = false;
      if (!_disposed) unawaited(load());
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _readHistoryService.removeListener(_scheduleReload);
    _sourceChanges?.removeListener(_handleSourceChanged);
    unawaited(_progressSubscription?.cancel());
    super.dispose();
  }
}
