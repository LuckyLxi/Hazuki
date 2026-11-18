import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

enum ComicDetailPluginTabStatus { loading, ready, failed }

class ComicDetailPluginTabState {
  const ComicDetailPluginTabState._(this.status, this.blocks, this.error);

  const ComicDetailPluginTabState.loading()
    : this._(ComicDetailPluginTabStatus.loading, const [], null);

  const ComicDetailPluginTabState.ready(List<SourceDetailTabBlock> blocks)
    : this._(ComicDetailPluginTabStatus.ready, blocks, null);

  const ComicDetailPluginTabState.failed(Object error)
    : this._(ComicDetailPluginTabStatus.failed, const [], error);

  final ComicDetailPluginTabStatus status;
  final List<SourceDetailTabBlock> blocks;
  final Object? error;
}

/// 管理插件声明的详情页标签页：打开详情时并行预取，各标签页独立失败与重试。
class ComicDetailPluginTabsController extends ChangeNotifier {
  ComicDetailPluginTabsController({
    required this.sourceUiService,
    required Future<List<SourceDetailTabBlock>> Function({
      required String comicId,
      required String tabId,
    })
    loadDetailTab,
    required String comicId,
    required this.tabs,
  }) : _loadDetailTab = loadDetailTab,
       _comicId = comicId;

  final Future<List<SourceDetailTabBlock>> Function({
    required String comicId,
    required String tabId,
  })
  _loadDetailTab;
  final String _comicId;
  final List<SourceDetailTab> tabs;

  final SourceUiService sourceUiService;
  late final _sourceUi = SourceUiOwner(sourceUiService);
  final Map<String, ComicDetailPluginTabState> _states = {};
  final Map<String, int> _requestIds = {};
  bool _disposed = false;

  ComicDetailPluginTabState stateOf(String tabId) =>
      _states[tabId] ?? const ComicDetailPluginTabState.loading();

  void initialize() {
    for (final tab in tabs) {
      unawaited(_load(tab.id));
    }
  }

  void retry(String tabId) {
    if (_disposed ||
        stateOf(tabId).status == ComicDetailPluginTabStatus.loading) {
      return;
    }
    unawaited(_load(tabId));
  }

  Future<void> _load(String tabId) async {
    // 重试会让旧请求的结果作废，避免慢的旧请求覆盖新结果。
    final requestId = (_requestIds[tabId] ?? 0) + 1;
    _requestIds[tabId] = requestId;
    _update(tabId, const ComicDetailPluginTabState.loading());
    ComicDetailPluginTabState next;
    try {
      final blocks = await _sourceUi.run(
        () => _loadDetailTab(comicId: _comicId, tabId: tabId),
      );
      next = ComicDetailPluginTabState.ready(blocks);
    } catch (error) {
      next = ComicDetailPluginTabState.failed(error);
    }
    if (_requestIds[tabId] != requestId) return;
    _update(tabId, next);
  }

  void _update(String tabId, ComicDetailPluginTabState state) {
    if (_disposed) return;
    _states[tabId] = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sourceUi.dispose();
    super.dispose();
  }
}
