part of '../../main.dart';

const Duration _searchLoadTimeout = Duration(seconds: 25);
const double _searchAppBarRevealOffset = 68;
const Map<String, String> _searchOrderLabels = {
  'mr': '最新',
  'mv': '总排行',
  'mv_m': '月排行',
  'mv_w': '周排行',
  'mv_t': '日排行',
  'mp': '最多图片',
  'tf': '最多喜欢',
};

class SearchPage extends StatelessWidget {
  const SearchPage({super.key, this.initialKeyword});

  final String? initialKeyword;

  @override
  Widget build(BuildContext context) {
    final keyword = initialKeyword?.trim() ?? '';
    if (keyword.isNotEmpty) {
      return SearchResultsPage(initialKeyword: keyword);
    }
    return const _SearchEntryPage();
  }
}

class _SearchEntryPage extends StatefulWidget {
  const _SearchEntryPage();

  @override
  State<_SearchEntryPage> createState() => _SearchEntryPageState();
}

class _SearchEntryPageState extends State<_SearchEntryPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<String> _historyList = [];
  bool _historyEditMode = false;
  bool _historyExpanded = false;
  double _searchRevealProgress = 0;

  bool get _showCollapsedSearch => _searchRevealProgress >= 0.94;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final nextReveal =
        (_scrollController.position.pixels / _searchAppBarRevealOffset).clamp(
          0.0,
          1.0,
        );
    if ((nextReveal - _searchRevealProgress).abs() < 0.01) {
      return;
    }
    setState(() {
      _searchRevealProgress = nextReveal;
    });
  }

  Future<void> _scrollToTop({bool focusSearch = false}) async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (focusSearch && mounted) {
      _searchFocusNode.requestFocus();
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _historyList = prefs.getStringList('search_history') ?? [];
      if (_historyList.isEmpty) {
        _historyEditMode = false;
      }
    });
  }

  Future<void> _removeHistory(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final newHistory = _historyList.where((e) => e != keyword).toList();
    await prefs.setStringList('search_history', newHistory);
    if (!mounted) {
      return;
    }
    setState(() {
      _historyList = newHistory;
      if (_historyList.isEmpty) {
        _historyEditMode = false;
      }
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    if (!mounted) {
      return;
    }
    setState(() {
      _historyList = [];
      _historyEditMode = false;
      _historyExpanded = false;
    });
  }

  Future<void> _openResults(String rawKeyword) async {
    final keyword = await _normalizeSubmittedKeyword(
      rawKeyword,
      controller: _searchController,
    );
    if (!mounted || keyword.isEmpty) {
      return;
    }

    _searchFocusNode.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchResultsPage(initialKeyword: keyword),
      ),
    );
    if (!mounted) {
      return;
    }
    unawaited(_loadHistory());
  }

  Future<void> _confirmClearHistory() async {
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) {
      return;
    }
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return AlertDialog(
          title: const Text('清空历史记录'),
          content: const Text('你确定要清空所有搜索记录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInBack,
          ).value,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
    if (confirm == true) {
      await _clearHistory();
    }
  }

  Widget _buildSearchBar({
    required String clearKey,
    required String submitKey,
  }) {
    return SizedBox(
      height: 56,
      child: SearchBar(
        focusNode: _searchFocusNode,
        controller: _searchController,
        hintText: '搜索漫画',
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        leading: const Icon(Icons.search),
        trailing: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                  reverseCurve: Curves.easeInCubic,
                ),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _searchController.text.isNotEmpty
                ? IconButton(
                    key: ValueKey(clearKey),
                    tooltip: '清空',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      _searchFocusNode.requestFocus();
                    },
                    icon: const Icon(Icons.close),
                  )
                : IconButton(
                    key: ValueKey(submitKey),
                    tooltip: '搜索',
                    onPressed: () =>
                        unawaited(_openResults(_searchController.text)),
                    icon: const Icon(Icons.arrow_forward),
                  ),
          ),
        ],
        onSubmitted: (_) => unawaited(_openResults(_searchController.text)),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildTopSearchBox() {
    final hideProgress = Curves.easeOutCubic.transform(_searchRevealProgress);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      child: Opacity(
        opacity: 1 - hideProgress,
        child: Transform.translate(
          offset: Offset(0, -10 * hideProgress),
          child: Transform.scale(
            scale: 1 - 0.04 * hideProgress,
            alignment: Alignment.topCenter,
            child: HeroMode(
              enabled: !_showCollapsedSearch,
              child: Hero(
                tag: _discoverSearchHeroTag,
                child: _buildSearchBar(
                  clearKey: 'entry-clear',
                  submitKey: 'entry-submit',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedSearchBox() {
    return HeroMode(
      enabled: _showCollapsedSearch,
      child: Hero(
        tag: _discoverSearchHeroTag,
        child: ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: _showCollapsedSearch ? 180 : 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSlide(
                offset: _showCollapsedSearch
                    ? Offset.zero
                    : const Offset(-0.08, 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedScale(
                  scale: _showCollapsedSearch ? 1 : 0.94,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _showCollapsedSearch ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !_showCollapsedSearch,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => unawaited(_scrollToTop(focusSearch: true)),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 40),
                          child: _buildSearchBar(
                            clearKey: 'entry-collapsed-clear',
                            submitKey: 'entry-collapsed-submit',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    if (_historyList.isEmpty) {
      return const SizedBox.shrink();
    }

    final isTooLong = _historyList.length > 24;
    final displayList = (_historyExpanded || !isTooLong)
        ? _historyList
        : _historyList.sublist(0, 24);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Text(
            '搜索历史',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: displayList.map((keyword) {
              if (_historyEditMode) {
                return InputChip(
                  label: Text(keyword),
                  deleteIcon: const Icon(Icons.cancel, size: 18),
                  onDeleted: () => _removeHistory(keyword),
                  onPressed: () => _removeHistory(keyword),
                );
              }
              return ActionChip(
                label: Text(keyword),
                onPressed: () => unawaited(_openResults(keyword)),
              );
            }).toList(),
          ),
        ),
        if (isTooLong)
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(top: 8),
            child: IconButton(
              icon: Icon(
                _historyExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed: () {
                setState(() {
                  _historyExpanded = !_historyExpanded;
                });
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: _historyList.isNotEmpty
          ? GestureDetector(
              onLongPress: _confirmClearHistory,
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _historyEditMode = !_historyEditMode;
                  });
                },
                child: Icon(
                  _historyEditMode ? Icons.done : Icons.delete_outline,
                ),
              ),
            )
          : null,
      appBar: hazukiFrostedAppBar(
        context: context,
        title: const Text('搜索'),
        actions: [
          _buildCollapsedSearchBox(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: _showCollapsedSearch ? 12 : 0,
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _buildTopSearchBox(),
          const SizedBox(height: 18),
          _buildHistoryView(),
        ],
      ),
    );
  }
}

Future<String> _normalizeSubmittedKeyword(
  String rawKeyword, {
  TextEditingController? controller,
}) async {
  var keyword = rawKeyword.trim();
  if (keyword.isEmpty) {
    return '';
  }

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('advanced_comic_id_search_enhance') == true) {
    final digitsOnly = keyword.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 2 && digitsOnly != keyword) {
      keyword = digitsOnly;
      controller?.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }
  }
  return keyword;
}

Future<void> _addSearchHistory(String keyword) async {
  if (keyword.isEmpty) {
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final history = prefs.getStringList('search_history') ?? const <String>[];
  final newHistory = [keyword, ...history.where((e) => e != keyword)];
  if (newHistory.length > 50) {
    newHistory.removeRange(50, newHistory.length);
  }
  await prefs.setStringList('search_history', newHistory);
}
