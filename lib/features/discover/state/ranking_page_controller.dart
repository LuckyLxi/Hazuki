import 'package:flutter/foundation.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/source_task_owner.dart';

/// 排行榜页面的状态控制器，负责排行榜选项加载、漫画列表分页与切换逻辑。
class RankingPageController extends ChangeNotifier {
  final SourceUiService sourceUiService;
  RankingPageController({
    required this.sourceUiService,
    required SourceCategoryGateway sourceService,
    required SourceTaskControlGateway taskControl,
    required String Function() optionsTimeoutMessage,
    required String Function() pageTimeoutMessage,
    required String Function(String) loadFailedMessage,
  }) : _sourceService = sourceService,
       _readTasks = SourceTaskOwner(taskControl),
       _optionsTimeoutMessage = optionsTimeoutMessage,
       _pageTimeoutMessage = pageTimeoutMessage,
       _loadFailedMessage = loadFailedMessage;

  static const _loadTimeout = Duration(seconds: 25);

  final SourceCategoryGateway _sourceService;
  final SourceTaskOwner _readTasks;
  late final SourceUiOwner _sourceUi = SourceUiOwner(sourceUiService);
  final String Function() _optionsTimeoutMessage;
  final String Function() _pageTimeoutMessage;
  final String Function(String) _loadFailedMessage;

  List<CategoryRankingOption> _options = const [];
  List<ExploreComic> _comics = const [];
  String? _selectedRanking;
  String? _errorMessage;
  bool _initialLoading = true;
  bool _refreshing = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _disposed = false;
  int _page = 1;
  int _initialRequest = 0;
  int _pageRequest = 0;

  List<CategoryRankingOption> get options => _options;
  List<ExploreComic> get comics => _comics;
  String? get selectedRanking => _selectedRanking;
  String? get errorMessage => _errorMessage;
  bool get initialLoading => _initialLoading;
  bool get refreshing => _refreshing;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;

  /// 初始化加载排行榜选项及首屏漫画数据
  Future<void> loadInitial({bool forceRefresh = false}) async {
    if (_disposed) return;
    final request = ++_initialRequest;
    _sourceUi.restart();
    _readTasks.restart();
    final generation = _readTasks.generation;
    if (forceRefresh) {
      _refreshing = true;
      notifyListeners();
    }

    try {
      final timeoutMessage = _optionsTimeoutMessage();
      final options = await _sourceUi.run(
        () => SourceUiScope.timeout(
          _sourceService.loadCategoryRankingOptions(
            taskOrigin: _readTasks.origin(),
          ),
          _loadTimeout,
          onTimeout: () => throw Exception(timeoutMessage),
        ),
      );
      if (_disposed ||
          generation != _readTasks.generation ||
          _sourceUi.wasCancelled) {
        return;
      }
      final selected = options.isEmpty
          ? null
          : (options.any((option) => option.value == _selectedRanking)
                ? _selectedRanking
                : options.first.value);
      _options = List.unmodifiable(options);
      _selectedRanking = selected;
      _comics = const [];
      _page = 1;
      _hasMore = selected != null;
      _errorMessage = null;
      notifyListeners();

      if (selected != null) await _loadPage(append: false);
    } catch (error) {
      if (_disposed || generation != _readTasks.generation) return;
      _errorMessage = _loadFailedMessage('$error');
      notifyListeners();
    } finally {
      if (!_disposed && request == _initialRequest) {
        _initialLoading = false;
        _refreshing = false;
        notifyListeners();
      }
    }
  }

  /// 切换当前选中的排行榜类型并重新加载首页
  Future<void> selectRanking(String value) async {
    if (_disposed || _selectedRanking == value) return;
    _selectedRanking = value;
    _loading = true;
    _loadingMore = false;
    _comics = const [];
    _page = 1;
    _hasMore = true;
    _errorMessage = null;
    notifyListeners();
    await _loadPage(append: false);
  }

  /// 加载更多排行榜漫画
  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    await _loadPage(append: true);
  }

  /// 加载指定分页的排行榜数据，处理防重与请求竞争
  Future<void> _loadPage({required bool append}) async {
    final option = _selectedRanking;
    if (_disposed || option == null || option.isEmpty) return;
    if (!append) _readTasks.restart();
    final targetPage = append ? _page + 1 : 1;
    final request = ++_pageRequest;
    _sourceUi.restart();

    if (append) {
      _loadingMore = true;
    } else {
      _loading = true;
      _comics = const [];
      _page = 1;
      _hasMore = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final timeoutMessage = _pageTimeoutMessage();
      final result = await _sourceUi.run(
        () => SourceUiScope.timeout(
          _sourceService.loadCategoryRankingComics(
            rankingOption: option,
            page: targetPage,
            taskOrigin: _readTasks.origin(),
          ),
          _loadTimeout,
          onTimeout: () => throw Exception(timeoutMessage),
        ),
      );
      if (_disposed || request != _pageRequest) return;
      final reachedMax =
          result.maxPage != null && targetPage >= result.maxPage!;
      final previousCount = _comics.length;
      if (append) {
        final merged = <String, ExploreComic>{
          for (final comic in _comics)
            if (comic.id.isNotEmpty) comic.id: comic,
          for (final comic in result.comics)
            if (comic.id.isNotEmpty) comic.id: comic,
        };
        _comics = List.unmodifiable(merged.values);
      } else {
        _comics = List.unmodifiable(result.comics);
      }
      _hasMore =
          !reachedMax &&
          result.comics.isNotEmpty &&
          (!append || _comics.length != previousCount);
      _page = targetPage;
      notifyListeners();
    } catch (error) {
      if (_disposed || request != _pageRequest) return;
      _errorMessage = _loadFailedMessage('$error');
      notifyListeners();
    } finally {
      if (!_disposed && request == _pageRequest) {
        _loading = false;
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _readTasks.dispose();
    _sourceUi.dispose();
    super.dispose();
  }
}
