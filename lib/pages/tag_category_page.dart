part of '../main.dart';

class TagCategoryPage extends StatefulWidget {
  const TagCategoryPage({super.key});

  @override
  State<TagCategoryPage> createState() => _TagCategoryPageState();
}

class _TagCategoryPageState extends State<TagCategoryPage> {
  static const _loadTimeout = Duration(seconds: 25);

  List<CategoryTagGroup> _tagGroups = const <CategoryTagGroup>[];

  String? _errorMessage;

  bool _initialLoading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  Future<List<CategoryTagGroup>> _loadTagGroups() {
    return HazukiSourceService.instance.loadCategoryTagGroups().timeout(
      _loadTimeout,
      onTimeout: () {
        throw Exception('标签分类加载超时，请稍后重试'); // 请求超时或网络错误处理
      },
    );
  }

  Future<void> _loadInitial({bool forceRefresh = false}) async {
    if (!mounted) {
      return;
    }

    if (forceRefresh) {
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final tagGroups = await _loadTagGroups();
      if (!mounted) {
        return;
      }

      setState(() {
        _tagGroups = tagGroups;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '标签分类加载失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _openSearchByTag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(initialKeyword: tag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: const Text('标签分类'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadInitial(forceRefresh: true),
        child: _initialLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HazukiStickerLoadingIndicator(size: 112),
                        SizedBox(height: 10),
                        Text('加载中...'),
                      ],
                    ),
                  ),
                ],
              )
            : (_errorMessage != null && _tagGroups.isEmpty)
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 90),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: FilledButton(
                          onPressed: () {
                            unawaited(_loadInitial(forceRefresh: true));
                          },
                          child: const Text('重试'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_tagGroups.isNotEmpty)
                        Text(
                          '标签分类',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      if (_tagGroups.isNotEmpty) const SizedBox(height: 10),
                      if (_tagGroups.isEmpty)
                        const Text('当前漫画源暂无标签分类'),
                      for (final group in _tagGroups)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: group.tags.map((tag) {
                                      return ActionChip(
                                        label: Text(tag),
                                        onPressed: () => _openSearchByTag(tag),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_refreshing)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: SizedBox.shrink(),
                        ),
                    ],
                  ),
      ),
    );
  }
}
