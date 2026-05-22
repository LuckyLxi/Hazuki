part of 'comments_page.dart';

class _CommentsCommentTile extends StatelessWidget {
  const _CommentsCommentTile({
    required this.comment,
    required this.index,
    required this.collapsedByFilter,
    required this.animatedCommentKeys,
    required this.supportLike,
    required this.supportReply,
    required this.supportReplies,
    required this.isLiking,
    required this.replies,
    required this.repliesExpanded,
    required this.repliesLoading,
    required this.repliesHasMore,
    required this.onReply,
    required this.onLike,
    required this.onToggleReplies,
    required this.onLoadMoreReplies,
  });

  final ComicCommentData comment;
  final int index;
  final bool collapsedByFilter;
  final Set<String> animatedCommentKeys;
  final bool supportLike;
  final bool supportReply;
  final bool supportReplies;
  final bool isLiking;
  final List<ComicCommentData> replies;
  final bool repliesExpanded;
  final bool repliesLoading;
  final bool repliesHasMore;
  final void Function(ComicCommentData comment) onReply;
  final void Function(ComicCommentData comment) onLike;
  final void Function(ComicCommentData comment) onToggleReplies;
  final void Function(String commentId) onLoadMoreReplies;

  @override
  Widget build(BuildContext context) {
    if (collapsedByFilter) {
      final key =
          comment.id ??
          '${comment.userName}|${comment.time}|${comment.content}';
      return _FilteredCommentTile(
        key: ValueKey('filtered_$key'),
        expandedBuilder: (context, onCollapse) => _CommentsCommentTileContent(
          comment: comment,
          index: index,
          animatedCommentKeys: animatedCommentKeys,
          supportLike: supportLike,
          supportReply: supportReply,
          supportReplies: supportReplies,
          isLiking: isLiking,
          replies: replies,
          repliesExpanded: repliesExpanded,
          repliesLoading: repliesLoading,
          repliesHasMore: repliesHasMore,
          onReply: onReply,
          onLike: onLike,
          onToggleReplies: onToggleReplies,
          onLoadMoreReplies: onLoadMoreReplies,
          animateIntro: false,
          filteredCollapseButton: _FilteredCommentCollapseButton(
            onCollapse: onCollapse,
          ),
        ),
      );
    }
    return _CommentsCommentTileContent(
      comment: comment,
      index: index,
      animatedCommentKeys: animatedCommentKeys,
      supportLike: supportLike,
      supportReply: supportReply,
      supportReplies: supportReplies,
      isLiking: isLiking,
      replies: replies,
      repliesExpanded: repliesExpanded,
      repliesLoading: repliesLoading,
      repliesHasMore: repliesHasMore,
      onReply: onReply,
      onLike: onLike,
      onToggleReplies: onToggleReplies,
      onLoadMoreReplies: onLoadMoreReplies,
    );
  }
}

class _CommentsCommentTileContent extends StatelessWidget {
  const _CommentsCommentTileContent({
    required this.comment,
    required this.index,
    required this.animatedCommentKeys,
    required this.supportLike,
    required this.supportReply,
    required this.supportReplies,
    required this.isLiking,
    required this.replies,
    required this.repliesExpanded,
    required this.repliesLoading,
    required this.repliesHasMore,
    required this.onReply,
    required this.onLike,
    required this.onToggleReplies,
    required this.onLoadMoreReplies,
    this.animateIntro = true,
    this.filteredCollapseButton,
  });

  final ComicCommentData comment;
  final int index;
  final Set<String> animatedCommentKeys;
  final bool supportLike;
  final bool supportReply;
  final bool supportReplies;
  final bool isLiking;
  final List<ComicCommentData> replies;
  final bool repliesExpanded;
  final bool repliesLoading;
  final bool repliesHasMore;
  final void Function(ComicCommentData comment) onReply;
  final void Function(ComicCommentData comment) onLike;
  final void Function(ComicCommentData comment) onToggleReplies;
  final void Function(String commentId) onLoadMoreReplies;
  final bool animateIntro;
  final Widget? filteredCollapseButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReply = (comment.replyCount ?? 0) > 0;
    final bodyStyle = theme.textTheme.bodyMedium;
    final metaStyle = theme.textTheme.bodySmall;
    final displayName = comment.userName.isEmpty
        ? l10n(context).commentsAnonymousUser
        : comment.userName;
    final animationKey =
        comment.id ?? '${comment.userName}|${comment.time}|${comment.content}';
    final shouldAnimate = animatedCommentKeys.add(animationKey);

    final item = Padding(
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
                    ?filteredCollapseButton,
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
                CommentsSelectableContent(
                  content: comment.content,
                  style: bodyStyle,
                  expansionKey: animationKey,
                ),
                if (comment.id != null &&
                    (supportLike || supportReply || supportReplies)) ...[
                  const SizedBox(height: 8),
                  _CommentActionRow(
                    comment: comment,
                    supportLike: supportLike,
                    supportReply: supportReply,
                    supportReplies: supportReplies,
                    isLiking: isLiking,
                    repliesExpanded: repliesExpanded,
                    onLike: onLike,
                    onReply: onReply,
                    onToggleReplies: onToggleReplies,
                  ),
                ],
                _AnimatedCommentReplies(
                  expanded: repliesExpanded && comment.id != null,
                  child: comment.id == null
                      ? const SizedBox.shrink()
                      : _CommentRepliesList(
                          parentId: comment.id!,
                          replies: replies,
                          loading: repliesLoading,
                          hasMore: repliesHasMore,
                          supportLike: supportLike,
                          supportReply: supportReply,
                          onReply: onReply,
                          onLike: onLike,
                          onLoadMore: onLoadMoreReplies,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!animateIntro || !shouldAnimate) {
      return item;
    }

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
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: item,
    );
  }
}

class _AnimatedCommentReplies extends StatelessWidget {
  const _AnimatedCommentReplies({required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SizeTransition(
              sizeFactor: curved,
              alignment: Alignment.topCenter,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            ),
          );
        },
        child: expanded
            ? Padding(
                key: const ValueKey<String>('replies-expanded'),
                padding: const EdgeInsets.only(top: 10),
                child: child,
              )
            : const SizedBox.shrink(key: ValueKey<String>('replies-collapsed')),
      ),
    );
  }
}

class _CommentActionRow extends StatelessWidget {
  const _CommentActionRow({
    required this.comment,
    required this.supportLike,
    required this.supportReply,
    required this.supportReplies,
    required this.isLiking,
    required this.repliesExpanded,
    required this.onLike,
    required this.onReply,
    required this.onToggleReplies,
  });

  final ComicCommentData comment;
  final bool supportLike;
  final bool supportReply;
  final bool supportReplies;
  final bool isLiking;
  final bool repliesExpanded;
  final void Function(ComicCommentData comment) onLike;
  final void Function(ComicCommentData comment) onReply;
  final void Function(ComicCommentData comment) onToggleReplies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final liked = comment.isLiked ?? false;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (supportReplies && (comment.replyCount ?? 0) > 0)
            TextButton.icon(
              onPressed: () => onToggleReplies(comment),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                repliesExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 18,
              ),
              label: Text(
                repliesExpanded
                    ? l10n(context).commentsHideReplies
                    : l10n(context).commentsReplyCount('${comment.replyCount}'),
              ),
            ),
          if (supportLike)
            TextButton.icon(
              onPressed: isLiking ? null : () => onLike(comment),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: liked ? theme.colorScheme.primary : null,
              ),
              icon: Icon(
                liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                size: 18,
              ),
              label: Text('${comment.score ?? 0}'),
            ),
          if (supportReply)
            IconButton(
              tooltip: l10n(context).commentsReplyTooltip,
              onPressed: () => onReply(comment),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.mode_comment_outlined, size: 20),
            ),
        ],
      ),
    );
  }
}

class _CommentRepliesList extends StatelessWidget {
  const _CommentRepliesList({
    required this.parentId,
    required this.replies,
    required this.loading,
    required this.hasMore,
    required this.supportLike,
    required this.supportReply,
    required this.onReply,
    required this.onLike,
    required this.onLoadMore,
  });

  final String parentId;
  final List<ComicCommentData> replies;
  final bool loading;
  final bool hasMore;
  final bool supportLike;
  final bool supportReply;
  final void Function(ComicCommentData comment) onReply;
  final void Function(ComicCommentData comment) onLike;
  final void Function(String commentId) onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(96),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < replies.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              _CommentReplyTile(
                comment: replies[i],
                supportLike: supportLike,
                supportReply: supportReply,
                onReply: onReply,
                onLike: onLike,
              ),
            ],
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox.square(
                    dimension: 36,
                    child: LoadingIndicatorM3E(),
                  ),
                ),
              )
            else if (hasMore)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => onLoadMore(parentId),
                  child: Text(l10n(context).commentsLoadReplies),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommentReplyTile extends StatelessWidget {
  const _CommentReplyTile({
    required this.comment,
    required this.supportLike,
    required this.supportReply,
    required this.onReply,
    required this.onLike,
  });

  final ComicCommentData comment;
  final bool supportLike;
  final bool supportReply;
  final void Function(ComicCommentData comment) onReply;
  final void Function(ComicCommentData comment) onLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = comment.userName.isEmpty
        ? l10n(context).commentsAnonymousUser
        : comment.userName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HazukiCachedCircleAvatar(
              url: comment.avatar,
              radius: 14,
              fallbackIcon: const Icon(Icons.person_outline, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.labelLarge),
                  if (comment.time.isNotEmpty)
                    Text(comment.time, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  CommentsSelectableContent(
                    content: comment.content,
                    style: theme.textTheme.bodyMedium,
                    expansionKey:
                        comment.id ??
                        '${comment.userName}|${comment.time}|${comment.content}',
                  ),
                ],
              ),
            ),
          ],
        ),
        if (comment.id != null && (supportLike || supportReply))
          _CommentActionRow(
            comment: comment,
            supportLike: supportLike,
            supportReply: supportReply,
            supportReplies: false,
            isLiking: false,
            repliesExpanded: false,
            onLike: onLike,
            onReply: onReply,
            onToggleReplies: (_) {},
          ),
      ],
    );
  }
}

class _FilteredCommentCollapseButton extends StatelessWidget {
  const _FilteredCommentCollapseButton({required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: l10n(context).comicDetailCollapse,
      onPressed: onCollapse,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        Icons.keyboard_arrow_up,
        size: 22,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _FilteredCommentTile extends StatefulWidget {
  const _FilteredCommentTile({super.key, required this.expandedBuilder});

  final Widget Function(BuildContext context, VoidCallback onCollapse)
  expandedBuilder;

  @override
  State<_FilteredCommentTile> createState() => _FilteredCommentTileState();
}

class _FilteredCommentTileState extends State<_FilteredCommentTile> {
  static const _animationDuration = Duration(milliseconds: 260);

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AnimatedSize(
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: _animationDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: const AlignmentDirectional(-1.0, -1.0),
              child: child,
            ),
          );
        },
        child: _expanded
            ? KeyedSubtree(
                key: const ValueKey<String>('filtered-comment-expanded'),
                child: widget.expandedBuilder(
                  context,
                  () => setState(() => _expanded = false),
                ),
              )
            : _FilteredCommentCollapsedTile(
                key: const ValueKey<String>('filtered-comment-collapsed'),
                label: strings.commentFilteredCollapsedLabel,
                expandLabel: strings.commentFilteredExpandLabel,
                onTap: () => setState(() => _expanded = true),
              ),
      ),
    );
  }
}

class _FilteredCommentCollapsedTile extends StatelessWidget {
  const _FilteredCommentCollapsedTile({
    super.key,
    required this.label,
    required this.expandLabel,
    required this.onTap,
  });

  final String label;
  final String expandLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        expandLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      onTap: onTap,
    );
  }
}
