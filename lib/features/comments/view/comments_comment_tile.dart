part of 'comments_page.dart';

class _CommentsCommentTile extends StatelessWidget {
  const _CommentsCommentTile({
    required this.comment,
    required this.index,
    required this.collapsedByFilter,
    required this.animatedCommentKeys,
    required this.onReply,
  });

  final ComicCommentData comment;
  final int index;
  final bool collapsedByFilter;
  final Set<String> animatedCommentKeys;
  final void Function(ComicCommentData comment) onReply;

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
          onReply: onReply,
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
      onReply: onReply,
    );
  }
}

class _CommentsCommentTileContent extends StatelessWidget {
  const _CommentsCommentTileContent({
    required this.comment,
    required this.index,
    required this.animatedCommentKeys,
    required this.onReply,
    this.animateIntro = true,
    this.filteredCollapseButton,
  });

  final ComicCommentData comment;
  final int index;
  final Set<String> animatedCommentKeys;
  final void Function(ComicCommentData comment) onReply;
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

    final item = InkWell(
      onTap: comment.id == null ? null : () => onReply(comment),
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
                          onPressed: () => onReply(comment),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.reply_outlined, size: 20),
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
                ],
              ),
            ),
          ],
        ),
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
