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
  static final RegExp _commentInlineImagePattern = RegExp(
    r'<img\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _commentBreakTagPattern = RegExp(
    r'<br\s*/?>',
    caseSensitive: false,
  );
  static final RegExp _commentBlockClosingTagPattern = RegExp(
    r'</(?:p|div|li)\s*>',
    caseSensitive: false,
  );
  static final RegExp _commentHtmlTagPattern = RegExp(r'<[^>]+>');
  static final RegExp _commentHtmlEntityPattern = RegExp(
    r'&(#x?[0-9A-Fa-f]+|[A-Za-z]+);',
  );

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
        _errorMessage = l10n(context).commentsLoadFailed('$e');
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
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).commentsLoginRequiredToSend,
          isError: true,
        ),
      );
      return;
    }

    if (!HazukiSourceService.instance.supportCommentSend) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).commentsSourceNotSupported,
          isError: true,
        ),
      );
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
      unawaited(showHazukiPrompt(context, l10n(context).commentsSendSuccess));
      await _loadInitial();
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).commentsSendFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingComment = false;
        });
      }
    }
  }

  Widget _buildCommentTile(ComicCommentData comment) {
    final theme = Theme.of(context);
    final hasReply = (comment.replyCount ?? 0) > 0;
    final bodyStyle = theme.textTheme.bodyMedium;
    final metaStyle = theme.textTheme.bodySmall;
    final displayName = comment.userName.isEmpty
        ? l10n(context).commentsAnonymousUser
        : comment.userName;

    return InkWell(
      onTap: comment.id == null ? null : () => _setReplyTarget(comment),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: HazukiCachedCircleAvatar(
                url: comment.avatar,
                fallbackIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (comment.id != null)
                        IconButton(
                          tooltip: l10n(context).commentsReplyTooltip,
                          onPressed: () => _setReplyTarget(comment),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.reply_outlined, size: 20),
                        ),
                    ],
                  ),
                  if (comment.time.isNotEmpty || hasReply) ...[
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (comment.time.isNotEmpty)
                          Text(comment.time, style: metaStyle),
                        if (hasReply)
                          Text(
                            l10n(
                              context,
                            ).commentsReplyCount('${comment.replyCount}'),
                            style: metaStyle,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildSelectableCommentContent(
                    comment.content,
                    bodyStyle,
                    expansionKey:
                        comment.id ??
                        '${comment.userName}|${comment.time}|${comment.content}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableCommentContent(
    String content,
    TextStyle? style, {
    required String expansionKey,
  }) {
    return _ExpandableCommentContent(
      key: ValueKey<String>(expansionKey),
      spans: _buildCommentContentSpans(content, style),
      plainText: _commentPreviewText(content),
      style: style,
    );
  }

  List<InlineSpan> _buildCommentContentSpans(String content, TextStyle? style) {
    if (content.isEmpty) {
      return const <InlineSpan>[];
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _commentInlineImagePattern.allMatches(content)) {
      if (match.start > start) {
        _appendCommentTextSpan(
          spans,
          content.substring(start, match.start),
          style,
        );
      }

      final tag = match.group(0);
      if (tag != null) {
        final source = _decodeCommentHtmlEntities(
          (_extractHtmlAttribute(tag, 'src') ?? '').trim(),
        );
        final alt = _normalizeCommentText(
          (_extractHtmlAttribute(tag, 'alt') ?? '').trim(),
        );
        if (source.isNotEmpty) {
          spans.add(
            _buildCommentImageSpan(source: source, alt: alt, style: style),
          );
        } else if (alt.isNotEmpty) {
          spans.add(TextSpan(text: alt, style: style));
        }
      }

      start = match.end;
    }

    if (start < content.length) {
      _appendCommentTextSpan(spans, content.substring(start), style);
    }

    if (spans.isEmpty) {
      final plainText = _normalizeCommentText(content);
      if (plainText.isNotEmpty) {
        spans.add(TextSpan(text: plainText, style: style));
      }
    }

    return spans;
  }

  void _appendCommentTextSpan(
    List<InlineSpan> spans,
    String rawText,
    TextStyle? style,
  ) {
    final text = _normalizeCommentText(rawText);
    if (text.isEmpty) {
      return;
    }
    spans.add(TextSpan(text: text, style: style));
  }

  InlineSpan _buildCommentImageSpan({
    required String source,
    required String alt,
    required TextStyle? style,
  }) {
    if (hazukiNoImageModeNotifier.value) {
      return TextSpan(text: alt.isEmpty ? '[表情]' : alt, style: style);
    }

    final baseFontSize =
        style?.fontSize ??
        Theme.of(context).textTheme.bodyMedium?.fontSize ??
        14;
    final imageSize = (baseFontSize * 1.25).clamp(16.0, 24.0).toDouble();
    final fallbackStyle = (style ?? const TextStyle()).copyWith(
      fontSize: baseFontSize * 0.85,
      height: 1,
    );
    final fallbackText = alt.isEmpty ? '[表情]' : alt;

    Widget buildFallback() {
      return SizedBox(
        width: imageSize,
        height: imageSize,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(fallbackText, style: fallbackStyle),
          ),
        ),
      );
    }

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: HazukiCachedImage(
          url: source,
          width: imageSize,
          height: imageSize,
          fit: BoxFit.contain,
          loading: buildFallback(),
          error: buildFallback(),
        ),
      ),
    );
  }

  String _commentPreviewText(String content) {
    if (content.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    var start = 0;
    for (final match in _commentInlineImagePattern.allMatches(content)) {
      if (match.start > start) {
        buffer.write(
          _normalizeCommentText(content.substring(start, match.start)),
        );
      }

      final tag = match.group(0);
      if (tag != null) {
        final alt = _normalizeCommentText(
          (_extractHtmlAttribute(tag, 'alt') ?? '').trim(),
        );
        if (alt.isNotEmpty) {
          buffer.write(alt);
        }
      }

      start = match.end;
    }

    if (start < content.length) {
      buffer.write(_normalizeCommentText(content.substring(start)));
    }

    return buffer
        .toString()
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeCommentText(String rawText) {
    if (rawText.isEmpty) {
      return '';
    }

    var text = rawText;
    text = text.replaceAll(_commentBreakTagPattern, '\n');
    text = text.replaceAll(_commentBlockClosingTagPattern, '\n');
    text = text.replaceAll(_commentHtmlTagPattern, '');
    return _decodeCommentHtmlEntities(text);
  }

  String _decodeCommentHtmlEntities(String input) {
    if (input.isEmpty) {
      return '';
    }

    return input.replaceAllMapped(_commentHtmlEntityPattern, (match) {
      final entity = match.group(1);
      if (entity == null || entity.isEmpty) {
        return match.group(0) ?? '';
      }

      if (entity.startsWith('#x') || entity.startsWith('#X')) {
        final codePoint = int.tryParse(entity.substring(2), radix: 16);
        return codePoint == null
            ? (match.group(0) ?? '')
            : String.fromCharCode(codePoint);
      }
      if (entity.startsWith('#')) {
        final codePoint = int.tryParse(entity.substring(1));
        return codePoint == null
            ? (match.group(0) ?? '')
            : String.fromCharCode(codePoint);
      }

      switch (entity.toLowerCase()) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
        case 'nbsp':
          return ' ';
        default:
          return match.group(0) ?? '';
      }
    });
  }

  String? _extractHtmlAttribute(String tag, String name) {
    final pattern = RegExp(
      "\\b${RegExp.escape(name)}\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))",
      caseSensitive: false,
    );
    final match = pattern.firstMatch(tag);
    return match?.group(1) ?? match?.group(2) ?? match?.group(3);
  }

  Widget _buildReplyBanner() {
    final replyTo = _replyToComment;
    if (replyTo == null) {
      return const SizedBox.shrink();
    }

    final name = replyTo.userName.isEmpty
        ? l10n(context).commentsAnonymousUser
        : replyTo.userName;
    final preview = _commentPreviewText(replyTo.content);

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
                  l10n(context).commentsReplyToUser(name),
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
            tooltip: l10n(context).commentsCancelReplyTooltip,
            onPressed: _clearReplyTarget,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomComposer() {
    final hint = _replyToComment == null
        ? l10n(context).commentsComposerHint
        : l10n(context).commentsReplyComposerHint(
            _replyToComment!.userName.isEmpty
                ? l10n(context).commentsAnonymousUser
                : _replyToComment!.userName,
          );

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
                    child: Text(
                      _sendingComment
                          ? l10n(context).commentsSending
                          : l10n(context).commentsSend,
                    ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HazukiStickerLoadingIndicator(size: 120),
            const SizedBox(height: 10),
            Text(l10n(context).commonLoading),
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
            FilledButton(
              onPressed: _loadInitial,
              child: Text(l10n(context).commonRetry),
            ),
          ],
        ),
      );
    } else if (_comments.isEmpty) {
      content = Container(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.only(top: 80),
        alignment: Alignment.topCenter,
        child: Text(l10n(context).commentsEmpty),
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
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HazukiStickerLoadingIndicator(size: 72),
                  const SizedBox(height: 8),
                  Text(l10n(context).commonLoading),
                ],
              ),
            ),
          )
        : const SizedBox(height: 8);

    final listBottomPadding = EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
    );

    final bodyList = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScrollNotification(notification);
        return false;
      },
      child: _comments.isNotEmpty
          ? CustomScrollView(
              controller: widget.isTabView ? null : _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: listBottomPadding,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == _comments.length) {
                        return loadMoreFooter;
                      }
                      final isLastComment = index == _comments.length - 1;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCommentTile(_comments[index]),
                          if (!isLastComment) const Divider(height: 1),
                        ],
                      );
                    }, childCount: _comments.length + 1),
                  ),
                ),
              ],
            )
          : ListView(
              controller: widget.isTabView ? null : _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: listBottomPadding,
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
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(l10n(context).commentsTitle),
      ),
      resizeToAvoidBottomInset: true,
      body: bodyList,
      // 独立页面模式：bottomNavigationBar + Scaffold 的 resizeToAvoidBottomInset 配合，
      // 无需再手动添加 viewInsets.bottom 偏移
      bottomNavigationBar: _buildBottomComposer(),
    );
  }
}

class _ExpandableCommentContent extends StatefulWidget {
  const _ExpandableCommentContent({
    super.key,
    required this.spans,
    required this.plainText,
    required this.style,
  });

  static const int collapsedMaxLines = 4;
  final List<InlineSpan> spans;
  final String plainText;
  final TextStyle? style;

  @override
  State<_ExpandableCommentContent> createState() =>
      _ExpandableCommentContentState();
}

class _ExpandableCommentContentState extends State<_ExpandableCommentContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.plainText, style: textStyle),
          maxLines: _ExpandableCommentContent.collapsedMaxLines,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              clipBehavior: Clip.hardEdge,
              child: SelectionArea(
                child: Builder(
                  builder: (context) {
                    final selectionColor =
                        theme.textSelectionTheme.selectionColor ??
                        theme.colorScheme.primary.withAlpha(56);
                    return RichText(
                      text: TextSpan(style: textStyle, children: widget.spans),
                      maxLines: _expanded || !isOverflowing
                          ? null
                          : _ExpandableCommentContent.collapsedMaxLines,
                      overflow: TextOverflow.clip,
                      selectionRegistrar: SelectionContainer.maybeOf(context),
                      selectionColor: selectionColor,
                    );
                  },
                ),
              ),
            ),
            if (isOverflowing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded
                              ? l10n(context).comicDetailCollapse
                              : l10n(context).comicDetailExpand,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          turns: _expanded ? 0.5 : 0,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
