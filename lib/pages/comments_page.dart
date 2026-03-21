part of '../main.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage({
    super.key,
    required this.comicId,
    this.subId,
    this.isTabView = false,
  });

  final String comicId;
  final String? subId;
  final bool isTabView;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage>
    with AutomaticKeepAliveClientMixin {
  static const _commentsLoadTimeout = Duration(seconds: 20);
  static const _pageSize = 16;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();

  List<ComicCommentData> _comments = const [];
  String? _errorMessage;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _sendingComment = false;
  int _currentPage = 1;
  int? _maxPage;
  ComicCommentData? _replyToComment;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      if (metrics.maxScrollExtent > 0 &&
          metrics.pixels >= metrics.maxScrollExtent - 220) {
        unawaited(_loadMore());
      }
    }
  }

  Future<ComicCommentsPageResult> _loadCommentsPage(int page) {
    return HazukiSourceService.instance
        .loadCommentsPage(
          comicId: widget.comicId,
          subId: widget.subId,
          page: page,
          pageSize: _pageSize,
        )
        .timeout(_commentsLoadTimeout);
  }

  List<ComicCommentData> _mergeComments(
    List<ComicCommentData> existing,
    List<ComicCommentData> incoming,
  ) {
    final merged = <String, ComicCommentData>{};
    for (final comment in existing) {
      final key = '${comment.userName}|${comment.time}|${comment.content}';
      merged[key] = comment;
    }
    for (final comment in incoming) {
      final key = '${comment.userName}|${comment.time}|${comment.content}';
      merged[key] = comment;
    }
    return merged.values.toList();
  }

  bool _computeHasMore({
    required int page,
    required int fetchedCount,
    int? maxPage,
  }) {
    if (maxPage != null) {
      return page < maxPage;
    }
    return fetchedCount >= _pageSize;
  }

  Future<void> _loadInitial() async {
    try {
      final pageResult = await _loadCommentsPage(1);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = pageResult.comments;
        _errorMessage = null;
        _currentPage = 1;
        _maxPage = pageResult.maxPage;
        _hasMore = _computeHasMore(
          page: 1,
          fetchedCount: pageResult.comments.length,
          maxPage: pageResult.maxPage,
        );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '加载评论失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!mounted || _initialLoading || _loadingMore || !_hasMore) {
      return;
    }

    if (_maxPage != null && _currentPage >= _maxPage!) {
      if (mounted) {
        setState(() {
          _hasMore = false;
        });
      }
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final pageResult = await _loadCommentsPage(nextPage);
      if (!mounted) {
        return;
      }

      final merged = _mergeComments(_comments, pageResult.comments);
      final hasMore = _computeHasMore(
        page: nextPage,
        fetchedCount: pageResult.comments.length,
        maxPage: pageResult.maxPage ?? _maxPage,
      );
      final appendedCount = merged.length - _comments.length;

      setState(() {
        _comments = merged;
        _currentPage = nextPage;
        _maxPage = pageResult.maxPage ?? _maxPage;
        _hasMore = hasMore && appendedCount > 0;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  void _setReplyTarget(ComicCommentData comment) {
    if (comment.id == null) {
      return;
    }
    setState(() {
      _replyToComment = comment;
    });
  }

  void _clearReplyTarget() {
    if (_replyToComment == null) {
      return;
    }
    setState(() {
      _replyToComment = null;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) {
      return;
    }

    if (!HazukiSourceService.instance.isLogged) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录后再评论')));
      return;
    }

    if (!HazukiSourceService.instance.supportCommentSend) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前漫画源不支持发送评论')));
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _sendingComment = true;
    });

    try {
      await HazukiSourceService.instance.sendComment(
        comicId: widget.comicId,
        subId: widget.subId,
        content: text,
        replyTo: _replyToComment?.id,
      );
      if (!mounted) {
        return;
      }
      _commentController.clear();
      setState(() {
        _replyToComment = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论发送成功')));
      await _loadInitial();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发送失败：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _sendingComment = false;
        });
      }
    }
  }

  Widget _buildCommentTile(ComicCommentData comment) {
    final hasReply = (comment.replyCount ?? 0) > 0;
    return ListTile(
      onTap: comment.id == null ? null : () => _setReplyTarget(comment),
      leading: HazukiCachedCircleAvatar(
        url: comment.avatar,
        fallbackIcon: const Icon(Icons.person_outline),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(comment.userName.isEmpty ? '匿名用户' : comment.userName),
          ),
          if (hasReply)
            Text(
              '回复 ${comment.replyCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comment.time.isNotEmpty) Text(comment.time),
          const SizedBox(height: 4),
          Text(comment.content),
        ],
      ),
      trailing: comment.id == null
          ? null
          : IconButton(
              tooltip: '回复',
              onPressed: () => _setReplyTarget(comment),
              icon: const Icon(Icons.reply_outlined),
            ),
    );
  }

  Widget _buildReplyBanner() {
    final replyTo = _replyToComment;
    if (replyTo == null) {
      return const SizedBox.shrink();
    }

    final name = replyTo.userName.isEmpty ? '匿名用户' : replyTo.userName;
    final preview = replyTo.content.replaceAll('\n', ' ').trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '回复 @$name',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: '取消回复',
            onPressed: _clearReplyTarget,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomComposer() {
    final hint = _replyToComment == null
        ? '写下你的评论…'
        : '回复 ${_replyToComment!.userName.isEmpty ? '匿名用户' : _replyToComment!.userName}…';

    // SafeArea 仅处理顶部，底部由外层布局（Scaffold bottomNavigationBar 或 Column）统一管理
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReplyBanner(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => unawaited(_submitComment()),
                      decoration: InputDecoration(
                        hintText: hint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _sendingComment ? null : _submitComment,
                    child: Text(_sendingComment ? '发送中…' : '发送'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget content;

    if (_initialLoading) {
      content = Container(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.only(top: 100),
        alignment: Alignment.topCenter,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HazukiStickerLoadingIndicator(size: 120),
            SizedBox(height: 10),
            Text('加载中...'),
          ],
        ),
      );
    } else if (_errorMessage != null && _comments.isEmpty) {
      content = Container(
        key: const ValueKey('error'),
        padding: const EdgeInsets.only(top: 80),
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_errorMessage!, textAlign: TextAlign.center),
            ),
            FilledButton(onPressed: _loadInitial, child: const Text('重试')),
          ],
        ),
      );
    } else if (_comments.isEmpty) {
      content = Container(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.only(top: 80),
        alignment: Alignment.topCenter,
        child: const Text('暂无评论'),
      );
    } else {
      content = ListView.separated(
        key: const ValueKey('list'),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _comments.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _buildCommentTile(_comments[index]),
      );
    }

    final loadMoreFooter = _loadingMore
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HazukiStickerLoadingIndicator(size: 72),
                  SizedBox(height: 8),
                  Text('加载中...'),
                ],
              ),
            ),
          )
        : const SizedBox(height: 8);

    final bodyList = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScrollNotification(notification);
        return false;
      },
      child: ListView(
        controller: widget.isTabView ? null : _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
        ),
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[
                  ...previousChildren,
                  ...<Widget?>[currentChild].whereType<Widget>(),
                ],
              );
            },
            child: content,
          ),
          loadMoreFooter,
        ],
      ),
    );

    if (widget.isTabView) {
      // tab 嵌入模式：Column 撑满全部高度，输入框紧贴底部
      // Scaffold 的 resizeToAvoidBottomInset 已自动处理键盘上推，此处不需要额外的 viewInsets 偏移
      return Column(
        children: [
          Expanded(child: bodyList),
          _buildBottomComposer(),
        ],
      );
    }

    return Scaffold(
      appBar: hazukiFrostedAppBar(context: context, title: const Text('评论')),
      resizeToAvoidBottomInset: true,
      body: bodyList,
      // 独立页面模式：bottomNavigationBar + Scaffold 的 resizeToAvoidBottomInset 配合，
      // 无需再手动添加 viewInsets.bottom 偏移
      bottomNavigationBar: _buildBottomComposer(),
    );
  }
}
