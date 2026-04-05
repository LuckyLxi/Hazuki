part of '../comments_page.dart';

extension _CommentsWidgetsExtension on _CommentsPageState {
  Widget _buildCommentTile(ComicCommentData comment, int index) {
    final theme = Theme.of(context);
    final hasReply = (comment.replyCount ?? 0) > 0;
    final bodyStyle = theme.textTheme.bodyMedium;
    final metaStyle = theme.textTheme.bodySmall;
    final displayName = comment.userName.isEmpty
        ? l10n(context).commentsAnonymousUser
        : comment.userName;

    final item = InkWell(
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

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index.clamp(0, 10)) * 60),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.85 + 0.15 * value,
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: item,
    );
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

  Widget _buildCommentsBodyList() {
    final content = _buildCommentsContent();
    final loadMoreFooter = _loadingMore
        ? const HazukiLoadMoreFooter()
        : const SizedBox(height: 4);

    final listBottomPadding = EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 10,
    );

    return NotificationListener<ScrollNotification>(
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
                          _buildCommentTile(_comments[index], index),
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
  }

  Widget _buildCommentsContent() {
    if (_initialLoading) {
      return Container(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.only(top: 100),
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HazukiSandyLoadingIndicator(size: 144),
            const SizedBox(height: 10),
            Text(l10n(context).commonLoading),
          ],
        ),
      );
    }

    if (_errorMessage != null && _comments.isEmpty) {
      return Container(
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
    }

    if (_comments.isEmpty) {
      return Container(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.only(top: 80),
        alignment: Alignment.topCenter,
        child: Text(l10n(context).commentsEmpty),
      );
    }

    return ListView.separated(
      key: const ValueKey('list'),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildCommentTile(_comments[index], index),
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
